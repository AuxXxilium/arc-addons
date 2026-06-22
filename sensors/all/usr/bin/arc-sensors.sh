#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Fan curve — three temperature points, one column per mode:
#
#          fullfan        coolfan        quietfan
#        temp  pwm%     temp  pwm%     temp  pwm%
DEFCURVE_MIN="20 50  20 30  20 20"
DEFCURVE_MID="35 75  40 50  45 30"
DEFCURVE_MAX="50 100 60 70  70 50"

# Runtime curve state — overridden by load_task from DB values
CURVE_MIN="${DEFCURVE_MIN}"
CURVE_MID="${DEFCURVE_MID}"
CURVE_MAX="${DEFCURVE_MAX}"
FANMODES=()

ESYNOSCHEDULER_DB="/usr/syno/etc/esynoscheduler/esynoscheduler.db"
FAN2GO_CONF="/etc/fan2go/fan2go.yaml"
FAN2GO_BIN="/usr/sbin/fan2go"
FAN_CHANNELS_CONF="/etc/fan2go/fan_channels.conf"

# Discovered fan channels (hwmonX/pwmY), populated by load_fan_channels / save_fan_channels
FAN_CHANNELS=()

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

# Derive FANMODES from CURVE_MIN/MAX.
# Call after setting CURVE_MIN/MID/MAX (either from DEFCURVE_* or from load_task).
derive_curve_vars() {
  local mn="${CURVE_MIN}" mx="${CURVE_MAX}"
  FANMODES=(
    "$(echo "${mn}" | awk '{print $1}') $(echo "${mx}" | awk '{print $1}')"
    "$(echo "${mn}" | awk '{print $3}') $(echo "${mx}" | awk '{print $3}')"
    "$(echo "${mn}" | awk '{print $5}') $(echo "${mx}" | awk '{print $5}')"
  )
}

# Read CURVE_MIN/MID/MAX from esynoscheduler DB task.
load_task() {
  CURVE_MIN="${DEFCURVE_MIN}"
  CURVE_MID="${DEFCURVE_MID}"
  CURVE_MAX="${DEFCURVE_MAX}"
  [ -f "${ESYNOSCHEDULER_DB}" ] || { derive_curve_vars; return; }
  local OP
  OP="$(sqlite3 "${ESYNOSCHEDULER_DB}" "SELECT operation FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"
  if [ -n "${OP}" ]; then
    eval "${OP}" 2>/dev/null || true
    [[ "${CURVE_MIN}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MIN="${DEFCURVE_MIN}"
    [[ "${CURVE_MID}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MID="${DEFCURVE_MID}"
    [[ "${CURVE_MAX}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]] || CURVE_MAX="${DEFCURVE_MAX}"
  fi
  derive_curve_vars
}

# Write the esynoscheduler task only if it doesn't exist yet (first boot).
# After that the CGI owns updates; we never overwrite user-edited values.
update_task() {
  [ -f "${ESYNOSCHEDULER_DB}" ] || return
  local exists
  exists="$(sqlite3 "${ESYNOSCHEDULER_DB}" "SELECT COUNT(*) FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"
  [ "${exists:-0}" -gt 0 ] && return

  local operation
  operation='# Fan curve — edit the values below to change fan behavior:
#
#          fullfan        coolfan        quietfan
#        temp  pwm%     temp  pwm%     temp  pwm%
CURVE_MIN="'"${CURVE_MIN}"'"
CURVE_MID="'"${CURVE_MID}"'"
CURVE_MAX="'"${CURVE_MAX}"'"'

  sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
INSERT INTO task VALUES('Fancontrol 2.0', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF
}

# Save discovered fan channels to persistent file (one hwmonX/pwmY per line).
save_fan_channels() {
  mkdir -p /etc/fan2go
  printf '%s\n' "${FAN_CHANNELS[@]}" >"${FAN_CHANNELS_CONF}"
}

# Load fan channels from persistent file into FAN_CHANNELS array.
load_fan_channels() {
  FAN_CHANNELS=()
  [ -f "${FAN_CHANNELS_CONF}" ] || return
  while IFS= read -r line; do
    [ -n "${line}" ] && FAN_CHANNELS+=("${line}")
  done <"${FAN_CHANNELS_CONF}"
}

# Discover hwmon fans with RPM > 0 and a matching writable pwm channel.
# Populates FAN_CHANNELS array.
discover_fans() {
  FAN_CHANNELS=()
  for HW in /sys/class/hwmon/hwmon*; do
    local IDX
    IDX="$(basename "${HW}" | sed 's/hwmon//')"
    for FAN in "${HW}"/fan[0-9]*_input; do
      [ -r "${FAN}" ] || continue
      local FNUM RPM
      FNUM="$(basename "${FAN}" | sed 's/fan\([0-9]*\)_input/\1/')"
      [ -w "${HW}/pwm${FNUM}" ] || continue
      RPM="$(cat "${FAN}" 2>/dev/null || echo 0)"
      [ "${RPM:-0}" -gt 0 ] || continue
      FAN_CHANNELS+=("hwmon${IDX}/pwm${FNUM}")
    done
  done
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
hwmon_platform() {
  local idx="${1}"
  local name
  name="$(cat "/sys/class/hwmon/hwmon${idx}/name" 2>/dev/null)"
  echo "${name:-hwmon${idx}}"
}

# Generate /etc/fan2go/fan2go.yaml from current CURVE_MIN/MID/MAX + FAN_CHANNELS + active mode index.
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

  # PWM percentages for this mode
  local _pwmcol=$(( MIDX * 2 + 2 ))
  local P_MIN P_MID P_MAX
  P_MIN="$(echo "${CURVE_MIN}" | awk "{print \$${_pwmcol}}")"
  P_MID="$(echo "${CURVE_MID}" | awk "{print \$${_pwmcol}}")"
  P_MAX="$(echo "${CURVE_MAX}" | awk "{print \$${_pwmcol}}")"
  local PWM_MIN PWM_MID PWM_MAX
  PWM_MIN="$(percent_to_pwm "${P_MIN}")"
  PWM_MID="$(percent_to_pwm "${P_MID}")"
  PWM_MAX="$(percent_to_pwm "${P_MAX}")"

  local CPU_SENSOR
  CPU_SENSOR="$(find_cpu_temp_sensor)"
  local CPU_HW_IDX CPU_TEMP_IDX CPU_PLATFORM
  CPU_HW_IDX="$(echo "${CPU_SENSOR}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
  CPU_TEMP_IDX="$(echo "${CPU_SENSOR}" | sed 's/.*temp\([0-9]*\)_input/\1/')"
  CPU_PLATFORM="$(hwmon_platform "${CPU_HW_IDX}")"

  # Load persisted startPwm:maxPwm values learned by fan2go during training
  local -A FAN_LEARNED_START=() FAN_LEARNED_MAX=()
  if [ -f /etc/fan2go/startpwm.conf ]; then
    while IFS='=' read -r fid val; do
      [ -n "${fid}" ] || continue
      FAN_LEARNED_START["${fid}"]="${val%%:*}"
      FAN_LEARNED_MAX["${fid}"]="${val#*:}"
    done </etc/fan2go/startpwm.conf
  fi

  mkdir -p /etc/fan2go

  {
    cat <<YAML
dbPath: /etc/fan2go/fan2go.db
runFanInitializationInParallel: false

fans:
YAML

    for chan in "${FAN_CHANNELS[@]}"; do
      local hw_idx fan_idx platform fan_id
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      platform="$(hwmon_platform "${hw_idx}")"
      fan_id="fan_${hw_idx}_${fan_idx}"

      local min_pwm=1
      local start_pwm="${FAN_LEARNED_START[${fan_id}]:-}"
      if [ -n "${start_pwm}" ] && [ "${start_pwm}" -ge 30 ] 2>/dev/null; then
        min_pwm="${start_pwm}"
      fi
      local curve_min="${PWM_MIN}"
      [ "${curve_min}" -lt "${min_pwm}" ] 2>/dev/null && curve_min="${min_pwm}"

      local max_pwm=255
      local learned_max="${FAN_LEARNED_MAX[${fan_id}]:-}"
      if [ -n "${learned_max}" ] && [ "${learned_max}" -gt 0 ] 2>/dev/null; then
        max_pwm="${learned_max}"
      fi

      cat <<YAML
  - id: "${fan_id}"
    hwmon:
      platform: "${platform}"
      rpmChannel: ${fan_idx}
      pwmChannel: ${fan_idx}
    neverStop: true
    minPwm: ${min_pwm}
    maxPwm: ${max_pwm}
    useUnscaledCurveValues: true
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

    for chan in "${FAN_CHANNELS[@]}"; do
      local hw_idx fan_idx
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"

      local fan_id="fan_${hw_idx}_${fan_idx}"
      local start_pwm="${FAN_LEARNED_START[${fan_id}]:-}"
      local curve_min="${PWM_MIN}"
      if [ -n "${start_pwm}" ] && [ "${start_pwm}" -ge 30 ] 2>/dev/null && [ "${curve_min}" -lt "${start_pwm}" ] 2>/dev/null; then
        curve_min="${start_pwm}"
      fi

      cat <<YAML
  - id: "curve_${hw_idx}_${fan_idx}"
    linear:
      sensor: cpu_temp
      steps:
        ${MINTEMP}: ${curve_min}
        ${MIDTEMP}: ${PWM_MID}
        ${MAXTEMP}: ${PWM_MAX}
YAML
    done

    cat <<YAML

fanController:
  adjustmentTickRate: 2000ms
  tempRollingWindowSize: 5
YAML
  } >"${FAN2GO_CONF}"
}

FAN2GO_PID=""
FAN2GO_WATCHER_PID=""
FAN2GO_LOG="/tmp/fan2go.log"

# Parse fan2go log for boundary lines and persist startPwm:maxPwm to
# /etc/fan2go/startpwm.conf as "fan_id=startPwm:maxPwm" lines.
# Uses two log patterns:
#   "PWM settings of fan 'ID': Min M, Start S, Max X"  — after DB reuse
#   "Fan ID: Analysis boundaries detected ... Start S, Max X" — after live sweep
# Runs in background after fan2go starts; exits once all fans are seen or 120s timeout.
watch_fan2go_pwm() {
  local log_offset="${1:-0}" conf="/etc/fan2go/startpwm.conf"
  local expected="${#FAN_CHANNELS[@]}" elapsed=0

  while [ "${elapsed}" -lt 120 ]; do
    sleep 3
    elapsed=$(( elapsed + 3 ))
    [ -f "${FAN2GO_LOG}" ] || continue

    local tmp_conf="" seen=0
    local -A start_map=() max_map=()

    while IFS= read -r line; do
      local fid
      if [[ "${line}" =~ PWM\ settings\ of\ fan\ \'([^\']+)\'.*Start\ ([0-9]+),\ Max\ ([0-9]+) ]]; then
        fid="${BASH_REMATCH[1]}"
        start_map["${fid}"]="${BASH_REMATCH[2]}"
        max_map["${fid}"]="${BASH_REMATCH[3]}"
      elif [[ "${line}" =~ Fan\ ([^:]+):\ Analysis\ boundaries\ detected.*Start\ ([0-9]+),\ Max\ ([0-9]+) ]]; then
        fid="${BASH_REMATCH[1]}"
        start_map["${fid}"]="${BASH_REMATCH[2]}"
        max_map["${fid}"]="${BASH_REMATCH[3]}"
      fi
    done < <(tail -n +"$(( log_offset + 1 ))" "${FAN2GO_LOG}" 2>/dev/null)

    for chan in "${FAN_CHANNELS[@]}"; do
      local hi fi fid
      hi="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fi="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      fid="fan_${hi}_${fi}"
      local sp="${start_map[${fid}]:-}" mp="${max_map[${fid}]:-}"
      [ -n "${sp}" ] && [ -n "${mp}" ] || continue
      tmp_conf+="${fid}=${sp}:${mp}"$'\n'
      seen=$(( seen + 1 ))
    done

    if [ "${seen}" -ge "${expected}" ]; then
      mkdir -p /etc/fan2go
      printf '%s' "${tmp_conf}" >"${conf}"
      echo "Saved startPwm/maxPwm for ${seen} fan(s) to ${conf}"
      break
    fi
  done
}

stop_fan2go() {
  if [ -n "${FAN2GO_WATCHER_PID}" ]; then
    kill "${FAN2GO_WATCHER_PID}" 2>/dev/null || true
    wait "${FAN2GO_WATCHER_PID}" 2>/dev/null || true
    FAN2GO_WATCHER_PID=""
  fi
  if [ -n "${FAN2GO_PID}" ]; then
    kill -9 "${FAN2GO_PID}" 2>/dev/null || true
    wait "${FAN2GO_PID}" 2>/dev/null || true
    FAN2GO_PID=""
  fi
}

restart_fan2go() {
  stop_fan2go
  mkdir -p /etc/fan2go
  local log_offset=0
  [ -f "${FAN2GO_LOG}" ] && log_offset="$(wc -l <"${FAN2GO_LOG}" 2>/dev/null || echo 0)"
  "${FAN2GO_BIN}" --config "${FAN2GO_CONF}" --no-style >>"${FAN2GO_LOG}" 2>&1 &
  FAN2GO_PID=$!
  watch_fan2go_pwm "${log_offset}" &
  FAN2GO_WATCHER_PID=$!
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

  discover_fans

  if [ "${#FAN_CHANNELS[@]}" -eq 0 ]; then
    echo "No controllable PWM fans found (fans present but RPM=0 or PWM not writable), skipping fan control..."
    set_fan_conf "no"
    return 1
  fi

  load_task
  save_fan_channels
  update_task
  return 0
}

start_fan2go() {
  local FanMode="${1:-1}"
  generate_fan2go_config "${FanMode}"
  restart_fan2go
}

fantype_to_mode() {
  case "$(/bin/get_key_value /etc/synoinfo.conf fan_config_type_internal 2>/dev/null)" in
    fullfan | full)  echo "0" ;;
    quietfan | low)  echo "2" ;;
    *)               echo "1" ;;
  esac
}

main() {
  local FanBaseMode="" FansActive=0 NoFanTick=0

  trap 'reload_config' HUP

  FanBaseMode="$(fantype_to_mode)"

  if init_fans; then
    FansActive=1
    start_fan2go "${FanBaseMode}"
  fi

  local SynoInfoMtime=""
  while true; do
    sleep 5

    if [ "${FansActive}" -eq 0 ]; then
      NoFanTick=$(( NoFanTick + 1 ))
      if [ "${NoFanTick}" -ge 6 ]; then
        NoFanTick=0
        if init_fans; then
          FansActive=1
          start_fan2go "${FanBaseMode}"
        fi
      fi
      continue
    fi

    # Reload triggered by arc-control save&apply or SIGHUP — check every tick
    if [ "${RELOAD_NEEDED}" -eq 1 ] || [ -f "${RELOAD_FLAG}" ]; then
      echo "Reloading fan curves..."
      RELOAD_NEEDED=0
      rm -f "${RELOAD_FLAG}"
      load_task
      load_fan_channels
      generate_fan2go_config "${FanBaseMode:-1}"
      restart_fan2go
      SynoInfoMtime="$(stat -c '%Y' /etc/synoinfo.conf 2>/dev/null)"
      continue
    fi

    # Mode change: only read synoinfo.conf when its mtime changed
    local mtime
    mtime="$(stat -c '%Y' /etc/synoinfo.conf 2>/dev/null)"
    if [ "${mtime}" != "${SynoInfoMtime}" ]; then
      SynoInfoMtime="${mtime}"
      local FanCurtMode
      FanCurtMode="$(fantype_to_mode)"

      if [ "${FanCurtMode}" != "${FanBaseMode}" ]; then
        echo "Fan mode changed to ${FanCurtMode}"
        FanBaseMode="${FanCurtMode}"
        load_task
        generate_fan2go_config "${FanBaseMode}"
        restart_fan2go
      fi
    fi
  done
}

cleanup() {
  stop_fan2go
  # Restore original PWM enable values saved in init_fans
  for key in "${!PWM_ENABLE_ORIG[@]}"; do
    [ -w "${key}" ] && echo "${PWM_ENABLE_ORIG[${key}]}" >"${key}" 2>/dev/null || true
  done
}

trap 'cleanup; exit' INT TERM HUP
main
