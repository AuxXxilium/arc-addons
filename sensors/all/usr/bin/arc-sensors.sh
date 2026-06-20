#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

#            fullfan        coolfan        quietfan
#               |              |              |
DEFMODES=("20 50 50 100" "20 60 20 60" "20 70 10 50")
#           ^  ^  ^  ^
#           1  2  3  4
# 1: MINTEMP  2: MAXTEMP  3: MINPWM  4: MAXPWM

# Default per-fan PWM% per mode: "full_min full_max:cool_min cool_max:quiet_min quiet_max"
DEF_FAN_PWM="50 100:20 60:10 50"

ESYNOSCHEDULER_DB="/usr/syno/etc/esynoscheduler/esynoscheduler.db"
FAN2GO_CONF="/etc/fan2go/fan2go.yaml"
FAN2GO_BIN="/usr/sbin/fan2go"

apply_amd_tctl_offset() {
  local offset=0 conf="/etc/sensors.d/k10temp-tdie.conf"
  grep -q 'AuthenticAMD' /proc/cpuinfo 2>/dev/null || return

  local hwmon_path pci_config
  hwmon_path="$(find /sys/class/hwmon -name 'name' -exec grep -lx 'k10temp' {} \; 2>/dev/null | head -1)"
  pci_config="$(readlink -f "$(dirname "${hwmon_path}")/device" 2>/dev/null)/config"
  if [ -w "${pci_config}" ] && [ -r "${pci_config}" ]; then
    printf '\x00\x98\x05\x00' | dd of="${pci_config}" bs=1 seek=184 count=4 conv=notrunc 2>/dev/null
    local b0 b1 b2 b3
    b0="$(dd if="${pci_config}" bs=1 skip=188 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    b1="$(dd if="${pci_config}" bs=1 skip=189 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    b2="$(dd if="${pci_config}" bs=1 skip=190 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    b3="$(dd if="${pci_config}" bs=1 skip=191 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    if [ -n "${b0}" ] && [ -n "${b1}" ] && [ -n "${b2}" ] && [ -n "${b3}" ]; then
      local bug
      bug="$(awk "BEGIN { v=strtonum(\"0x${b3}\") * 16777216 + strtonum(\"0x${b2}\") * 65536 + strtonum(\"0x${b1}\") * 256 + strtonum(\"0x${b0}\"); print (int(v/524288)%2==0 && int(v/65536)%4==3) ? 1 : 0 }")"
      [ "${bug}" = "1" ] && offset=-49
    fi
  fi

  mkdir -p /etc/sensors.d
  if [ "${offset}" -ne 0 ]; then
    printf 'chip "k10temp-*"\n    compute temp1 @+(%d), @-(%d)\n' "${offset}" "${offset}" >"${conf}"
  else
    rm -f "${conf}"
  fi
}

set_fan_conf() {
  for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do
    for K in "support_fan" "support_fan_adjust_dual_mode" "supportadt7490"; do
      /usr/syno/bin/synosetkeyvalue "${F}" "${K}" "${1:-"no"}"
    done
  done
}

percent_to_pwm() {
  local P="${1}"
  [ "${P}" -lt 0 ] && P=0
  [ "${P}" -gt 100 ] && P=100
  echo $(( P * 255 / 100 ))
}

# Read task operation from esynoscheduler DB and eval into shell variables.
# Sets: FANMODES array, FAN_CURVES array (may be empty).
load_task() {
  FANMODES=("${DEFMODES[@]}")
  FAN_CURVES=()
  [ -f "${ESYNOSCHEDULER_DB}" ] || return
  local OP
  OP="$(synowebapi -s --exec api=SYNO.Core.EventScheduler method=get task_name=\"Fancontrol\" 2>/dev/null | jq -r '.data.operation' 2>/dev/null)"
  [ -n "${OP}" ] || return
  eval "${OP}" 2>/dev/null || true
  # Ensure FANMODES has valid entries
  for i in 0 1 2; do
    [[ "${FANMODES[$i]}" =~ ^[0-9]+\ [0-9]+\ [0-9]+\ [0-9]+$ ]] || FANMODES[$i]="${DEFMODES[$i]}"
  done
}

# Discover all hwmon fans that have a matching pwm channel.
# Outputs lines: "hwmonX/pwmY"
discover_fans() {
  for HW in /sys/class/hwmon/hwmon*; do
    local IDX
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    for FAN in "${HW}"/fan[0-9]*_input; do
      [ -r "${FAN}" ] || continue
      local FNUM RPM
      FNUM="$(basename "${FAN}" | sed 's/fan\([0-9]*\)_input/\1/')"
      RPM="$(cat "${FAN}" 2>/dev/null)"
      [ "${RPM:-0}" -le 0 ] && continue
      [ -w "${HW}/pwm${FNUM}" ] || continue
      echo "hwmon${IDX}/pwm${FNUM}"
    done
  done
}

# Merge discovered fans with existing FAN_CURVES array.
# Preserves user values for known channels, adds defaults for new ones,
# removes entries for channels that no longer exist.
merge_fan_curves() {
  local -a discovered=("$@")
  local -A existing=()

  # Index existing FAN_CURVES by channel key
  for entry in "${FAN_CURVES[@]}"; do
    local key="${entry%%:*}"
    local val="${entry#*:}"
    existing["${key}"]="${val}"
  done

  FAN_CURVES=()
  for chan in "${discovered[@]}"; do
    if [ -n "${existing[${chan}]}" ]; then
      # Validate: must have 3 colon-separated pairs of 2 numbers each
      local v="${existing[${chan}]}"
      local f1 f2 f3
      f1="$(echo "${v}" | cut -d: -f1)"
      f2="$(echo "${v}" | cut -d: -f2)"
      f3="$(echo "${v}" | cut -d: -f3)"
      if [[ "${f1}" =~ ^[0-9]+\ [0-9]+$ ]] && [[ "${f2}" =~ ^[0-9]+\ [0-9]+$ ]] && [[ "${f3}" =~ ^[0-9]+\ [0-9]+$ ]]; then
        FAN_CURVES+=("${chan}:${v}")
      else
        FAN_CURVES+=("${chan}:${DEF_FAN_PWM}")
      fi
    else
      FAN_CURVES+=("${chan}:${DEF_FAN_PWM}")
    fi
  done
}

# Write merged FAN_CURVES back into the esynoscheduler task.
update_task() {
  [ -f "${ESYNOSCHEDULER_DB}" ] || return

  # Build FAN_CURVES bash array literal
  local curves_str="FAN_CURVES=("$'\n'
  for entry in "${FAN_CURVES[@]}"; do
    curves_str+="  \"${entry}\""$'\n'
  done
  curves_str+=")"

  local modes_comment='# Fan modes: MINTEMP MAXTEMP MINPWM MAXPWM (temps shared, PWM overridable per fan below)
#                       fullfan             coolfan               quietfan
#                          |                      |                        |'
  local curves_comment='# Per-fan PWM% per mode: "hwmonX/pwmY:full_min full_max:cool_min cool_max:quiet_min quiet_max"
# Edit MINPWM/MAXPWM values. Entries are auto-managed (added/removed) on boot.'

  local operation
  operation="${modes_comment}
FANMODES=(\"${FANMODES[0]}\" \"${FANMODES[1]}\" \"${FANMODES[2]}\")

${curves_comment}
${curves_str}"

  sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
INSERT INTO task VALUES('Fancontrol', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF
}

# Find the best CPU temp sensor path (hwmonX/tempY_input).
find_cpu_temp_sensor() {
  # Prefer coretemp / k10temp / zenpower
  local P
  P="$(find /sys/class/hwmon -name 'name' 2>/dev/null | xargs grep -lE '^(coretemp|k10temp|zenpower)$' 2>/dev/null | head -1)"
  if [ -n "${P}" ]; then
    local HW
    HW="$(dirname "${P}")"
    local IDX
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    echo "hwmon${IDX}/temp1_input"
    return
  fi
  # Fallback: first temp sensor found
  for HW in /sys/class/hwmon/hwmon*; do
    [ -r "${HW}/temp1_input" ] || continue
    local IDX
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    echo "hwmon${IDX}/temp1_input"
    return
  done
}

# Get hwmon platform name for a hwmonX index.
hwmon_platform() {
  cat "/sys/class/hwmon/hwmon${1}/name" 2>/dev/null || echo "hwmon${1}"
}

# Generate /etc/fan2go/fan2go.yaml from current FANMODES + FAN_CURVES + active mode index.
# $1: mode index (0=fullfan, 1=coolfan, 2=quietfan)
generate_fan2go_config() {
  local MIDX="${1:-1}"
  local FANMODE="${FANMODES[${MIDX}]}"
  [[ "${FANMODE}" =~ ^([0-9]+)\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)$ ]] || FANMODE="${DEFMODES[${MIDX}]}"

  local MINTEMP MAXTEMP
  MINTEMP="$(echo "${FANMODE}" | cut -d' ' -f1)"
  MAXTEMP="$(echo "${FANMODE}" | cut -d' ' -f2)"

  local CPU_SENSOR
  CPU_SENSOR="$(find_cpu_temp_sensor)"
  local CPU_HW_IDX CPU_TEMP_IDX
  CPU_HW_IDX="$(echo "${CPU_SENSOR}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
  CPU_TEMP_IDX="$(echo "${CPU_SENSOR}" | sed 's/.*temp\([0-9]*\)_input/\1/')"
  local CPU_PLATFORM
  CPU_PLATFORM="$(hwmon_platform "${CPU_HW_IDX}")"

  mkdir -p /etc/fan2go

  {
    cat <<YAML
dbPath: /var/lib/fan2go/fan2go.db
runFanInitializationInParallel: true

fans:
YAML

    # Emit one fan entry per FAN_CURVES entry
    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      local platform
      platform="$(hwmon_platform "${hw_idx}")"

      # Pick PWM% for active mode (field 1=full, 2=cool, 3=quiet; 1-based)
      local mode_field=$(( MIDX + 1 ))
      local pwm_pair
      pwm_pair="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"
      local MINPWM_P MAXPWM_P
      MINPWM_P="$(echo "${pwm_pair}" | cut -d' ' -f1)"
      MAXPWM_P="$(echo "${pwm_pair}" | cut -d' ' -f2)"
      local MINPWM MAXPWM
      MINPWM="$(percent_to_pwm "${MINPWM_P}")"
      MAXPWM="$(percent_to_pwm "${MAXPWM_P}")"
      [ "${MAXPWM}" -le "${MINPWM}" ] && MAXPWM=$(( MINPWM + 26 ))

      cat <<YAML
  - id: "fan_${hw_idx}_${fan_idx}"
    hwmon:
      platform: "${platform}"
      index: ${hw_idx}
      rpmChannel: ${fan_idx}
      pwmChannel: ${fan_idx}
    neverStop: true
    minPwm: ${MINPWM}
    maxPwm: ${MAXPWM}
    curve: "curve_${hw_idx}_${fan_idx}"
YAML
    done

    cat <<YAML

sensors:
  - id: cpu_temp
    hwmon:
      platform: "${CPU_PLATFORM}"
      index: ${CPU_HW_IDX}
      tempChannel: ${CPU_TEMP_IDX}

curves:
YAML

    # Emit one curve per fan with smooth linear steps across the temp range
    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"

      local mode_field=$(( MIDX + 1 ))
      local pwm_pair
      pwm_pair="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"
      local MINPWM_P MAXPWM_P
      MINPWM_P="$(echo "${pwm_pair}" | cut -d' ' -f1)"
      MAXPWM_P="$(echo "${pwm_pair}" | cut -d' ' -f2)"

      # Build smooth steps: interpolate 5 points between MINTEMP→MAXTEMP / MINPWM→MAXPWM
      local steps=""
      local NSTEPS=5
      for i in $(seq 0 ${NSTEPS}); do
        local temp pwm_p
        temp=$(( MINTEMP + (MAXTEMP - MINTEMP) * i / NSTEPS ))
        pwm_p=$(( MINPWM_P + (MAXPWM_P - MINPWM_P) * i / NSTEPS ))
        steps+="        - {temp: ${temp}, pwm: ${pwm_p}}"$'\n'
      done

      cat <<YAML
  - id: "curve_${hw_idx}_${fan_idx}"
    linear:
      sensor: cpu_temp
      steps:
${steps}
YAML
    done

    cat <<YAML

fanController:
  adjustmentTickRate: 200ms
  tempRollingWindowSize: 10
YAML
  } >"${FAN2GO_CONF}"
}

restart_fan2go() {
  pkill -f "${FAN2GO_BIN}" 2>/dev/null
  for _w in 1 2 3 4 5; do
    pkill -0 -f "${FAN2GO_BIN}" 2>/dev/null || break
    sleep 1
  done
  "${FAN2GO_BIN}" --config "${FAN2GO_CONF}" --no-style >/dev/null 2>&1 &
}

RELOAD_FLAG="/run/arc-sensors.reload"
RELOAD_NEEDED=0

get_task_hash() {
  [ -f "${ESYNOSCHEDULER_DB}" ] || echo ""
  sqlite3 "${ESYNOSCHEDULER_DB}" "SELECT operation FROM task WHERE task_name='Fancontrol';" 2>/dev/null | md5sum | cut -d' ' -f1
}

reload_config() {
  RELOAD_NEEDED=1
}

init_fans() {
  apply_amd_tctl_offset

  if [ -z "$(find /sys/ -name "fan*_input" 2>/dev/null)" ]; then
    echo "No fan detected, skipping fan control..."
    set_fan_conf "no"
    return 1
  fi

  set_fan_conf "yes"

  for PWM_ENABLE in /sys/class/hwmon/hwmon*/pwm*_enable; do
    [[ "${PWM_ENABLE}" =~ pwm([0-9]+)_enable$ ]] && [ -w "${PWM_ENABLE}" ] && echo 1 >"${PWM_ENABLE}"
  done

  local -a DISCOVERED
  mapfile -t DISCOVERED < <(discover_fans)

  if [ "${#DISCOVERED[@]}" -eq 0 ]; then
    echo "No controllable PWM fans found, skipping fan control..."
    set_fan_conf "no"
    return 1
  fi

  load_task
  merge_fan_curves "${DISCOVERED[@]}"
  update_task
  return 0
}

main() {
  local FanBaseMode="" FanTaskHash="" FansActive=0 NoFanTick=0

  trap 'reload_config' HUP

  if init_fans; then
    FansActive=1
    FanTaskHash="$(get_task_hash)"
  fi

  while true; do
    sleep 1

    # Recheck for fans every 30s if none were found initially
    if [ "${FansActive}" -eq 0 ]; then
      NoFanTick=$(( NoFanTick + 1 ))
      if [ "${NoFanTick}" -ge 30 ]; then
        NoFanTick=0
        if init_fans; then
          FansActive=1
          FanBaseMode=""
          FanTaskHash=""
        fi
      fi
      continue
    fi

    # Handle reload request (SIGHUP or flag file)
    if [ "${RELOAD_NEEDED}" -eq 1 ] || [ -f "${RELOAD_FLAG}" ]; then
      echo "Reloading fan curves..."
      RELOAD_NEEDED=0
      rm -f "${RELOAD_FLAG}"
      load_task
      merge_fan_curves $(discover_fans)
      update_task
      FanTaskHash="$(get_task_hash)"
      generate_fan2go_config "${FanBaseMode:-1}"
      restart_fan2go
      continue
    fi

    local FanType FanCurtMode
    FanType="$(/bin/get_key_value /etc/synoinfo.conf fan_config_type_internal 2>/dev/null)"
    case "${FanType}" in
      fullfan | full)   FanCurtMode="0" ;;
      coolfan | high)   FanCurtMode="1" ;;
      quietfan | low)   FanCurtMode="2" ;;
      *)                FanCurtMode="1" ;;
    esac

    # Check if task body changed (user edited curves in DSM)
    local CurHash
    CurHash="$(get_task_hash)"
    if [ "${CurHash}" != "${FanTaskHash}" ]; then
      echo "Fan task changed, reloading curves..."
      FanTaskHash="${CurHash}"
      load_task
      FanBaseMode=""  # force mode re-apply below
    fi

    if [ "${FanCurtMode}" != "${FanBaseMode}" ]; then
      echo "Fan mode changed to ${FanCurtMode} (${FanType})"
      FanBaseMode="${FanCurtMode}"
      generate_fan2go_config "${FanBaseMode}"
      restart_fan2go
    fi

    find /etc -maxdepth 1 -type f -name 'synoinfo.conf.??????' -mmin +0.5 -exec rm -f {} \; 2>/dev/null
  done
}

trap 'pkill -f "${FAN2GO_BIN}" 2>/dev/null' EXIT INT TERM
main
