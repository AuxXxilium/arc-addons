#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Fan curve definition — three temperature points, one column per mode:
#
#          fullfan        coolfan        quietfan
#        temp  pwm%     temp  pwm%     temp  pwm%
# MIN:    20 @  50       20 @  20       20 @  20
# MID:    35 @  75       40 @  50       45 @  30
# MAX:    50 @ 100       60 @  60       70 @  50
#
# Each row: TEMP_FULL PWM_FULL  TEMP_COOL PWM_COOL  TEMP_QUIET PWM_QUIET
DEFCURVE_MIN="20 50  20 30  20 20"
DEFCURVE_MID="35 75  40 50  45 30"
DEFCURVE_MAX="50 100 60 70  70 50"

# Runtime curve state — overridden by load_task from DB values
CURVE_MIN="${DEFCURVE_MIN}"
CURVE_MID="${DEFCURVE_MID}"
CURVE_MAX="${DEFCURVE_MAX}"
FANMODES=()
DEF_FAN_PWM=""

ESYNOSCHEDULER_DB="/usr/syno/etc/esynoscheduler/esynoscheduler.db"
FAN2GO_CONF="/etc/fan2go/fan2go.yaml"
FAN2GO_BIN="/usr/sbin/fan2go"

apply_amd_tctl_offset() {
  local offset=0 conf="/etc/sensors.d/k10temp-tdie.conf"
  grep -q 'AuthenticAMD' /proc/cpuinfo 2>/dev/null || return

  local hwmon_path pci_config
  local _hw
  for _hw in /sys/class/hwmon/hwmon*; do
    [ "$(cat "${_hw}/name" 2>/dev/null)" = "k10temp" ] && { hwmon_path="${_hw}/name"; break; }
  done
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

# Derive FANMODES and DEF_FAN_PWM from CURVE_MIN/MID/MAX.
# Call after setting those three variables (either from DEFCURVE_* or from load_task).
derive_curve_vars() {
  local mn="${CURVE_MIN}" md="${CURVE_MID}" mx="${CURVE_MAX}"
  FANMODES=(
    "$(echo "${mn}" | awk '{print $1}') $(echo "${mx}" | awk '{print $1}')"
    "$(echo "${mn}" | awk '{print $3}') $(echo "${mx}" | awk '{print $3}')"
    "$(echo "${mn}" | awk '{print $5}') $(echo "${mx}" | awk '{print $5}')"
  )
  DEF_FAN_PWM="$(echo "${mn}" | awk '{print $2}') $(echo "${md}" | awk '{print $2}') $(echo "${mx}" | awk '{print $2}'):$(echo "${mn}" | awk '{print $4}') $(echo "${md}" | awk '{print $4}') $(echo "${mx}" | awk '{print $4}'):$(echo "${mn}" | awk '{print $6}') $(echo "${md}" | awk '{print $6}') $(echo "${mx}" | awk '{print $6}')"
}

# Read task from esynoscheduler DB.
# Loads CURVE_MIN/MID/MAX (user-editable), derives FANMODES + DEF_FAN_PWM,
# and loads FAN_CURVES (auto-managed, not user-editable).
load_task() {
  CURVE_MIN="${DEFCURVE_MIN}"
  CURVE_MID="${DEFCURVE_MID}"
  CURVE_MAX="${DEFCURVE_MAX}"
  FAN_CURVES=()
  [ -f "${ESYNOSCHEDULER_DB}" ] || { derive_curve_vars; return; }
  local OP
  OP="$(sqlite3 "${ESYNOSCHEDULER_DB}" ".timeout 5000
SELECT operation FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"
  if [ -n "${OP}" ]; then
    eval "${OP}" 2>/dev/null || true
    # Validate loaded curve rows: must be 6 numbers each
    [[ "${CURVE_MIN}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MIN="${DEFCURVE_MIN}"
    [[ "${CURVE_MID}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MID="${DEFCURVE_MID}"
    [[ "${CURVE_MAX}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MAX="${DEFCURVE_MAX}"
  fi
  derive_curve_vars
}

# Discover all hwmon fans that have RPM > 0 and a matching writable pwm channel.
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
      [ "${RPM:-0}" -gt 0 ] || continue
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
      # Validate: 3 colon-separated mode pairs "min max:min max:min max"
      local v="${existing[${chan}]}"
      local f1 f2 f3
      f1="$(echo "${v}" | cut -d: -f1)"
      f2="$(echo "${v}" | cut -d: -f2)"
      f3="$(echo "${v}" | cut -d: -f3)"
      if [[ "${f1}" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]] && [[ "${f2}" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]] && [[ "${f3}" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]]; then
        FAN_CURVES+=("${chan}:${v}")
      else
        FAN_CURVES+=("${chan}:${DEF_FAN_PWM}")
      fi
    else
      FAN_CURVES+=("${chan}:${DEF_FAN_PWM}")
    fi
  done
}

# Write the esynoscheduler task.
# If the task doesn't exist yet: write the full template including default CURVE_* values.
# If it already exists: only update the auto-managed FAN_CURVES section, preserving user edits.
update_task() {
  [ -f "${ESYNOSCHEDULER_DB}" ] || return

  local fan_curves_str="FAN_CURVES=("$'\n'
  for entry in "${FAN_CURVES[@]}"; do
    fan_curves_str+="  \"${entry}\""$'\n'
  done
  fan_curves_str+=")"

  local exists
  exists="$(sqlite3 "${ESYNOSCHEDULER_DB}" ".timeout 5000
SELECT COUNT(*) FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"

  if [ "${exists:-0}" -eq 0 ]; then
    # First boot — write full template with default curve values
    local operation
    operation='# Fan curve definition — edit the three rows below to change fan behavior:
#
#          fullfan        coolfan        quietfan
#        temp  pwm%     temp  pwm%     temp  pwm%
# MIN:   '"${DEFCURVE_MIN}"'
# MID:   '"${DEFCURVE_MID}"'
# MAX:   '"${DEFCURVE_MAX}"'
#
# Each row: TEMP_FULL PWM_FULL  TEMP_COOL PWM_COOL  TEMP_QUIET PWM_QUIET
CURVE_MIN="'"${DEFCURVE_MIN}"'"
CURVE_MID="'"${DEFCURVE_MID}"'"
CURVE_MAX="'"${DEFCURVE_MAX}"'"

# --- auto-managed below, do not edit ---
'"${fan_curves_str}"
    sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
.timeout 5000
INSERT INTO task VALUES('Fancontrol 2.0', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF
  else
    # Task exists — replace only the auto-managed section, leave user edits above it intact
    local cur_op new_op
    cur_op="$(sqlite3 "${ESYNOSCHEDULER_DB}" ".timeout 5000
SELECT operation FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"
    # Strip everything from the separator line down and append fresh FAN_CURVES
    new_op="$(printf '%s' "${cur_op}" | sed '/^# --- auto-managed below/,$d')"
    new_op="${new_op}# --- auto-managed below, do not edit ---
${fan_curves_str}"
    sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
.timeout 5000
UPDATE task SET operation='$(printf '%s' "${new_op}" | sed "s/'/''/g")' WHERE task_name='Fancontrol 2.0';
EOF
  fi
}

# Find the best CPU temp sensor path (hwmonX/tempY_input).
find_cpu_temp_sensor() {
  local HW IDX name
  for HW in /sys/class/hwmon/hwmon*; do
    [ -r "${HW}/name" ] || continue
    name="$(cat "${HW}/name" 2>/dev/null)"
    case "${name}" in coretemp|k10temp|zenpower)
      IDX="$(basename "${HW}" | sed 's/hwmon//')"
      echo "hwmon${IDX}/temp1_input"
      return
    esac
  done
  for HW in /sys/class/hwmon/hwmon*; do
    [ -r "${HW}/temp1_input" ] || continue
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    echo "hwmon${IDX}/temp1_input"
    return
  done
}

# Get fan2go platform string for a hwmonX index.
# fan2go matches the platform field as a regex against the chip name read by libsensors,
# which is just the bare chip name (e.g. "nct6775", "coretemp"). Use that directly.
hwmon_platform() {
  local idx="${1}"
  local name
  name="$(cat "/sys/class/hwmon/hwmon${idx}/name" 2>/dev/null)"
  echo "${name:-hwmon${idx}}"
}

# Generate /etc/fan2go/fan2go.yaml from current FANMODES + FAN_CURVES + active mode index.
# $1: mode index (0=fullfan, 1=coolfan, 2=quietfan)
generate_fan2go_config() {
  local MIDX="${1:-1}"
  [ "${#FANMODES[@]}" -eq 0 ] && derive_curve_vars
  local FANMODE="${FANMODES[${MIDX}]}"
  local MINTEMP MIDTEMP MAXTEMP
  local _tempcol=$(( MIDX * 2 + 1 ))
  MINTEMP="$(echo "${FANMODE}" | cut -d' ' -f1)"
  MAXTEMP="$(echo "${FANMODE}" | cut -d' ' -f2)"
  MIDTEMP="$(echo "${CURVE_MID}" | awk "{print \$${_tempcol}}")"

  local CPU_SENSOR
  CPU_SENSOR="$(find_cpu_temp_sensor)"
  local CPU_HW_IDX CPU_TEMP_IDX CPU_PLATFORM
  CPU_HW_IDX="$(echo "${CPU_SENSOR}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
  CPU_TEMP_IDX="$(echo "${CPU_SENSOR}" | sed 's/.*temp\([0-9]*\)_input/\1/')"
  CPU_PLATFORM="$(hwmon_platform "${CPU_HW_IDX}")"

  local mode_field=$(( MIDX + 1 ))

  mkdir -p /etc/fan2go /var/lib/fan2go

  {
    cat <<YAML
dbPath: /var/lib/fan2go/fan2go.db
runFanInitializationInParallel: true

fans:
YAML

    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx platform
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      platform="$(hwmon_platform "${hw_idx}")"

      local pwm_triple
      pwm_triple="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"
      local MINPWM_P MIDPWM_P MAXPWM_P MINPWM MAXPWM
      MINPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f1)"
      MIDPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f2)"
      MAXPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f3)"
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
      channel: ${CPU_TEMP_IDX}

curves:
YAML

    for entry in "${FAN_CURVES[@]}"; do
      local chan="${entry%%:*}"
      local pwm_vals="${entry#*:}"
      local hw_idx fan_idx
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"

      local pwm_triple
      pwm_triple="$(echo "${pwm_vals}" | cut -d: -f"${mode_field}")"
      local MINPWM_P MIDPWM_P MAXPWM_P
      MINPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f1)"
      MIDPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f2)"
      MAXPWM_P="$(echo "${pwm_triple}" | cut -d' ' -f3)"

      cat <<YAML
  - id: "curve_${hw_idx}_${fan_idx}"
    linear:
      sensor: cpu_temp
      steps:
        ${MINTEMP}: ${MINPWM_P}
        ${MIDTEMP}: ${MIDPWM_P}
        ${MAXTEMP}: ${MAXPWM_P}
YAML
    done

    cat <<YAML

fanController:
  adjustmentTickRate: 200ms
  tempRollingWindowSize: 10
YAML
  } >"${FAN2GO_CONF}"
}

stop_fan2go() {
  pkill -f "${FAN2GO_BIN}" 2>/dev/null || true
  for _w in 1 2 3 4 5; do
    pkill -0 -f "${FAN2GO_BIN}" 2>/dev/null || return
    sleep 1
  done
  pkill -9 -f "${FAN2GO_BIN}" 2>/dev/null || true
}

restart_fan2go() {
  stop_fan2go
  mkdir -p /etc/fan2go /var/lib/fan2go
  "${FAN2GO_BIN}" --config "${FAN2GO_CONF}" --no-style >/dev/null 2>&1 &
}

RELOAD_FLAG="/run/arc-sensors.reload"
RELOAD_NEEDED=0
declare -A PWM_ENABLE_ORIG=()

reload_config() {
  RELOAD_NEEDED=1
}

init_fans() {
  apply_amd_tctl_offset
  # libsensors requires /etc/sensors3.conf — ensure it exists even if tgz was older
  [ -f /etc/sensors3.conf ] || touch /etc/sensors3.conf

  local _fan_found=0
  for _f in /sys/class/hwmon/hwmon*/fan[0-9]*_input; do
    [ -r "${_f}" ] && { _fan_found=1; break; }
  done
  if [ "${_fan_found}" -eq 0 ]; then
    echo "No fan detected, skipping fan control..."
    set_fan_conf "no"
    return 1
  fi

  set_fan_conf "yes"

  # Save original pwm*_enable values and switch to manual mode so pwm* nodes become writable
  for PWM_ENABLE in /sys/class/hwmon/hwmon*/pwm*_enable; do
    [[ "${PWM_ENABLE}" =~ pwm([0-9]+)_enable$ ]] || continue
    [ -w "${PWM_ENABLE}" ] || continue
    [ -z "${PWM_ENABLE_ORIG[${PWM_ENABLE}]}" ] && PWM_ENABLE_ORIG["${PWM_ENABLE}"]="$(cat "${PWM_ENABLE}" 2>/dev/null)"
    echo 1 >"${PWM_ENABLE}"
  done

  local -a DISCOVERED
  mapfile -t DISCOVERED < <(discover_fans)

  if [ "${#DISCOVERED[@]}" -eq 0 ]; then
    echo "No controllable PWM fans found (fans present but RPM=0 or PWM not writable), skipping fan control..."
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

cleanup() {
  stop_fan2go
  # Restore original PWM enable values saved in init_fans
  for key in "${!PWM_ENABLE_ORIG[@]}"; do
    [ -w "${key}" ] && echo "${PWM_ENABLE_ORIG[${key}]}" >"${key}" 2>/dev/null || true
  done
}

trap 'cleanup' EXIT INT TERM
main
