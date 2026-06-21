#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

#         fullfan coolfan quietfan
#            |       |       |
DEFMODES=("30 70" "30 80" "30 90")
#           ^  ^
#           1  2
# 1: MINTEMP  2: MAXTEMP

# Default per-fan 3 points per mode: "t1@p1 t2@p2 t3@p3:t1@p1 t2@p2 t3@p3:t1@p1 t2@p2 t3@p3"
#                                      fullfan            coolfan            quietfan
DEF_FAN_PWM="30@50 50@75 70@100:30@20 55@50 80@80:30@20 60@35 90@60"

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

# Validate a single mode string of 3 points: "t1@p1 t2@p2 t3@p3"
valid_mode_points() {
  [[ "${1}" =~ ^[0-9]+@[0-9]+\ [0-9]+@[0-9]+\ [0-9]+@[0-9]+$ ]]
}

# Read task operation from esynoscheduler DB and eval into shell variables.
# Sets: FANMODES array, FAN_CURVES array (may be empty).
load_task() {
  FANMODES=("${DEFMODES[@]}")
  FAN_CURVES=()
  [ -f "${ESYNOSCHEDULER_DB}" ] || return
  local OP
  OP="$(synowebapi -s --exec api=SYNO.Core.EventScheduler method=get task_name=\"Fancontrol 2.0\" 2>/dev/null | jq -r '.data.operation' 2>/dev/null)"
  [ -n "${OP}" ] || return
  eval "${OP}" 2>/dev/null || true
  # Ensure FANMODES has valid entries
  for i in 0 1 2; do
    [[ "${FANMODES[$i]}" =~ ^[0-9]+\ [0-9]+$ ]] || FANMODES[$i]="${DEFMODES[$i]}"
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

  for entry in "${FAN_CURVES[@]}"; do
    local key="${entry%%:*}"
    local val="${entry#*:}"
    existing["${key}"]="${val}"
  done

  FAN_CURVES=()
  for chan in "${discovered[@]}"; do
    if [ -n "${existing[${chan}]}" ]; then
      # Validate: 3 colon-separated mode strings, each "t%p t%p t%p"
      local v="${existing[${chan}]}"
      local f1 f2 f3
      f1="$(echo "${v}" | cut -d: -f1)"
      f2="$(echo "${v}" | cut -d: -f2)"
      f3="$(echo "${v}" | cut -d: -f3)"
      if valid_mode_points "${f1}" && valid_mode_points "${f2}" && valid_mode_points "${f3}"; then
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

  local curves_str="FAN_CURVES=("$'\n'
  for entry in "${FAN_CURVES[@]}"; do
    curves_str+="  \"${entry}\""$'\n'
  done
  curves_str+=")"

  local modes_comment='# Fan modes: "MINTEMP MAXTEMP" — temperature range per mode, shared across all fans
#              fullfan   coolfan   quietfan'
  local curves_comment='# Per-fan 3-point curve per mode: "hwmonX/pwmY:t1@p1 t2@p2 t3@p3:t1@p1 t2@p2 t3@p3:t1@p1 t2@p2 t3@p3"
# Each point is temp@pwm% (e.g. 30@50 = at 30C run at 50% PWM). Three modes: fullfan:coolfan:quietfan. Auto-managed on boot.'

  local operation
  operation="${modes_comment}
FANMODES=(\"${FANMODES[0]}\" \"${FANMODES[1]}\" \"${FANMODES[2]}\")

${curves_comment}
${curves_str}"

  sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol 2.0';
INSERT INTO task VALUES('Fancontrol 2.0', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF
}

# Find the best CPU temp sensor path (hwmonX/tempY_input).
find_cpu_temp_sensor() {
  local P
  P="$(find /sys/class/hwmon -name 'name' 2>/dev/null | xargs grep -lE '^(coretemp|k10temp|zenpower)$' 2>/dev/null | head -1)"
  if [ -n "${P}" ]; then
    local HW IDX
    HW="$(dirname "${P}")"
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    echo "hwmon${IDX}/temp1_input"
    return
  fi
  for HW in /sys/class/hwmon/hwmon*; do
    [ -r "${HW}/temp1_input" ] || continue
    local IDX
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    echo "hwmon${IDX}/temp1_input"
    return
  done
}

# Get fan2go platform string for a hwmonX index.
# fan2go needs e.g. "coretemp-isa-0000" or "nct6798-isa-0290".
# /sys/devices/platform/NAME.DECIMAL → NAME-isa-HEXADDR (zero-padded to 4 digits)
hwmon_platform() {
  local idx="${1}"
  local name dev_path dev_name dec hex
  name="$(cat "/sys/class/hwmon/hwmon${idx}/name" 2>/dev/null)"
  [ -z "${name}" ] && echo "hwmon${idx}" && return
  dev_path="$(readlink -f "/sys/class/hwmon/hwmon${idx}/device" 2>/dev/null)"
  dev_name="$(basename "${dev_path}")"
  # Extract decimal suffix after the last dot (e.g. "coretemp.0" → 0, "nct6775.656" → 656)
  dec="$(echo "${dev_name}" | grep -oE '\.[0-9]+$' | tr -d '.')"
  if [ -n "${dec}" ]; then
    hex="$(printf '%04x' "${dec}")"
    echo "${name}-isa-${hex}"
  else
    echo "${name}"
  fi
}

# Generate /etc/fan2go/fan2go.yaml from current FANMODES + FAN_CURVES + active mode index.
# $1: mode index (0=fullfan, 1=coolfan, 2=quietfan)
generate_fan2go_config() {
  local MIDX="${1:-1}"
  local FANMODE="${FANMODES[${MIDX}]}"
  [[ "${FANMODE}" =~ ^([0-9]+)\ ([0-9]+)$ ]] || FANMODE="${DEFMODES[${MIDX}]}"

  local CPU_SENSOR
  CPU_SENSOR="$(find_cpu_temp_sensor)"
  local CPU_HW_IDX CPU_TEMP_IDX CPU_PLATFORM
  CPU_HW_IDX="$(echo "${CPU_SENSOR}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
  CPU_TEMP_IDX="$(echo "${CPU_SENSOR}" | sed 's/.*temp\([0-9]*\)_input/\1/')"
  CPU_PLATFORM="$(hwmon_platform "${CPU_HW_IDX}")"

  mkdir -p /etc/fan2go

  {
    cat <<YAML
dbPath: /etc/fan2go/fan2go.db
runFanInitializationInParallel: true

fans:
YAML

    local mode_field=$(( MIDX + 1 ))

    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx platform
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      platform="$(hwmon_platform "${hw_idx}")"

      # Parse the 3-point string for the active mode: "t1%p1 t2%p2 t3%p3"
      local mode_pts
      mode_pts="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"

      # Extract min and max PWM% from first and last points for fan envelope
      local pt1 pt3
      pt1="$(echo "${mode_pts}" | cut -d' ' -f1)"
      pt3="$(echo "${mode_pts}" | cut -d' ' -f3)"
      local MINPWM_P MAXPWM_P MINPWM MAXPWM
      MINPWM_P="$(echo "${pt1}" | cut -d'@' -f2)"
      MAXPWM_P="$(echo "${pt3}" | cut -d'@' -f2)"
      MINPWM="$(percent_to_pwm "${MINPWM_P}")"
      MAXPWM="$(percent_to_pwm "${MAXPWM_P}")"
      [ "${MAXPWM}" -le "${MINPWM}" ] && MAXPWM=$(( MINPWM + 26 ))

      cat <<YAML
  - id: "fan_${hw_idx}_${fan_idx}"
    hwmon:
      platform: "${platform}"
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
      index: ${CPU_TEMP_IDX}

curves:
YAML

    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"

      local mode_pts
      mode_pts="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"

      # Emit steps in fan2go format: "- TEMP_MILLIDEG: PWM%"
      # fan2go reads hwmon temps in millidegrees, so multiply °C by 1000
      local steps=""
      for pt in $(echo "${mode_pts}"); do
        local t p
        t=$(( $(echo "${pt}" | cut -d'@' -f1) * 1000 ))
        p="$(echo "${pt}" | cut -d'@' -f2)"
        steps+="        - ${t}: ${p}%"$'\n'
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
  local pid
  pid="$(ps aux 2>/dev/null | grep -F "${FAN2GO_BIN}" | grep -v grep | awk '{print $2}' | head -1)"
  if [ -n "${pid}" ]; then
    kill "${pid}" 2>/dev/null
    for _w in 1 2 3 4 5; do
      kill -0 "${pid}" 2>/dev/null || break
      sleep 1
    done
    kill -9 "${pid}" 2>/dev/null || true
  fi
  mkdir -p /etc/fan2go /var/lib/fan2go
  LD_LIBRARY_PATH=/usr/lib "${FAN2GO_BIN}" --config "${FAN2GO_CONF}" --no-style >/dev/null 2>&1 &
}

RELOAD_FLAG="/run/arc-sensors.reload"
RELOAD_NEEDED=0

reload_config() {
  RELOAD_NEEDED=1
}

init_fans() {
  apply_amd_tctl_offset
  # libsensors requires /etc/sensors3.conf — ensure it exists even if tgz was older
  [ -f /etc/sensors3.conf ] || touch /etc/sensors3.conf


  if [ -z "$(find /sys/class/hwmon/ -name "fan*_input" 2>/dev/null)" ]; then
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

start_fan2go() {
  local FanMode="${1:-1}"
  generate_fan2go_config "${FanMode}"
  restart_fan2go
}

main() {
  local FanBaseMode="" FansActive=0 NoFanTick=0

  trap 'reload_config' HUP

  # Determine initial fan mode
  local FanType
  FanType="$(/bin/get_key_value /etc/synoinfo.conf fan_config_type_internal 2>/dev/null)"
  case "${FanType}" in
    fullfan | full)   FanBaseMode="0" ;;
    coolfan | high)   FanBaseMode="1" ;;
    quietfan | low)   FanBaseMode="2" ;;
    *)                FanBaseMode="1" ;;
  esac

  if init_fans; then
    FansActive=1
    start_fan2go "${FanBaseMode}"
  fi

  while true; do
    sleep 1

    if [ "${FansActive}" -eq 0 ]; then
      NoFanTick=$(( NoFanTick + 1 ))
      if [ "${NoFanTick}" -ge 30 ]; then
        NoFanTick=0
        if init_fans; then
          FansActive=1
          start_fan2go "${FanBaseMode}"
        fi
      fi
      continue
    fi

    # Reload triggered by arc-control save&apply or SIGHUP
    if [ "${RELOAD_NEEDED}" -eq 1 ] || [ -f "${RELOAD_FLAG}" ]; then
      echo "Reloading fan curves..."
      RELOAD_NEEDED=0
      rm -f "${RELOAD_FLAG}"
      load_task
      merge_fan_curves $(discover_fans)
      update_task
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

    if [ "${FanCurtMode}" != "${FanBaseMode}" ]; then
      echo "Fan mode changed to ${FanCurtMode} (${FanType})"
      FanBaseMode="${FanCurtMode}"
      load_task
      generate_fan2go_config "${FanBaseMode}"
      restart_fan2go
    fi

    find /etc -maxdepth 1 -type f -name 'synoinfo.conf.??????' -mmin +0.5 -exec rm -f {} \; 2>/dev/null
  done
}

trap 'kill $(ps aux 2>/dev/null | grep -F "${FAN2GO_BIN}" | grep -v grep | awk "{print \$2}" | head -1) 2>/dev/null' EXIT INT TERM
main
