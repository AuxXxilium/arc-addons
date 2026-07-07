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

# Runtime curve state — overridden by load_task from DB values.
# Per-fan overrides use variables named CURVE_MIN_<key>/CURVE_MID_<key>/CURVE_MAX_<key>,
# where <key> is the sanitized "chip_pwmN" identifier from fan_curve_key(). Any fan without
# a matching override falls back to the global CURVE_MIN/MID/MAX below.
CURVE_MIN="${DEFCURVE_MIN}"
CURVE_MID="${DEFCURVE_MID}"
CURVE_MAX="${DEFCURVE_MAX}"
FANMODES=()

# Space-separated list of fan_curve_key() identifiers (e.g. "nct6775_pwm2") to leave under
# BIOS/hardware automatic control instead of fan2go. Set via FAN_EXCLUDE in the DB task.
FAN_EXCLUDE=""

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

# Derive FANMODES (temp min/max per mode) from a MIN/MAX curve pair.
# $1: CURVE_MIN-style string, $2: CURVE_MAX-style string. Defaults to the global curve.
derive_curve_vars() {
  local mn="${1:-${CURVE_MIN}}" mx="${2:-${CURVE_MAX}}"
  FANMODES=(
    "$(echo "${mn}" | awk '{print $1}') $(echo "${mx}" | awk '{print $1}')"
    "$(echo "${mn}" | awk '{print $3}') $(echo "${mx}" | awk '{print $3}')"
    "$(echo "${mn}" | awk '{print $5}') $(echo "${mx}" | awk '{print $5}')"
  )
}

# Sanitize a hwmon chip name + pwm index into a bash-identifier-safe key, e.g. "nct6775_pwm1".
fan_curve_key() {
  local hw_idx="${1}" fan_idx="${2}" platform
  platform="$(hwmon_platform "${hw_idx}")"
  platform="$(printf '%s' "${platform}" | tr -c 'A-Za-z0-9' '_')"
  echo "${platform}_pwm${fan_idx}"
}

# True if the given fan_curve_key() identifier is listed in FAN_EXCLUDE.
fan_is_excluded() {
  local key="${1}" x
  for x in ${FAN_EXCLUDE}; do
    [ "${x}" = "${key}" ] && return 0
  done
  return 1
}

# Echo "MIN|MID|MAX" curve strings for a given fan key, using its CURVE_*_<key> override
# if present and valid, else falling back to the global CURVE_MIN/MID/MAX.
curve_for_fan_key() {
  local key="${1}"
  local -n _min="CURVE_MIN_${key}" _mid="CURVE_MID_${key}" _max="CURVE_MAX_${key}"
  local pattern='^[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+$'
  if [[ "${_min:-}" =~ ${pattern} ]] && [[ "${_mid:-}" =~ ${pattern} ]] && [[ "${_max:-}" =~ ${pattern} ]]; then
    echo "${_min}|${_mid}|${_max}"
  else
    echo "${CURVE_MIN}|${CURVE_MID}|${CURVE_MAX}"
  fi
}

# Read CURVE_MIN/MID/MAX (+ any per-fan CURVE_*_<key> overrides) from esynoscheduler DB task.
load_task() {
  CURVE_MIN="${DEFCURVE_MIN}"
  CURVE_MID="${DEFCURVE_MID}"
  CURVE_MAX="${DEFCURVE_MAX}"
  FAN_EXCLUDE=""

  # Clear per-fan overrides from any previous load so removed/renamed entries don't linger.
  local _stale
  for _stale in $(compgen -v -X '!CURVE_MIN_*'; compgen -v -X '!CURVE_MID_*'; compgen -v -X '!CURVE_MAX_*'); do
    unset "${_stale}"
  done

  [ -f "${ESYNOSCHEDULER_DB}" ] || { derive_curve_vars; return; }
  local OP
  OP="$(sqlite3 "${ESYNOSCHEDULER_DB}" "SELECT operation FROM task WHERE task_name='Fancontrol 2.0';" 2>/dev/null)"
  if [ -n "${OP}" ]; then
    eval "${OP}" 2>/dev/null || true
    [[ "${FAN_EXCLUDE}" =~ ^[A-Za-z0-9_\ ]*$ ]] || FAN_EXCLUDE=""
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
CURVE_MAX="'"${CURVE_MAX}"'"
#
# Optional per-fan overrides — uncomment and edit to set a different curve for a
# specific PWM controller. <key> below is "<chip>_pwm<N>"; any fan without a matching
# override uses the CURVE_MIN/MID/MAX above.'"$(fan_curve_examples)"'
#
# Optional exclusion list — space-separated "<chip>_pwm<N>" keys (same <key> as above) to
# leave under BIOS/hardware automatic control instead of fan2go, e.g.:
#FAN_EXCLUDE="'"$(fan_exclude_example)"'"
'

  sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
INSERT INTO task VALUES('Fancontrol 2.0', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF
}

# Build commented example CURVE_*_<key> lines for every discovered fan, for the
# first-boot task template written by update_task().
fan_curve_examples() {
  local chan hw_idx fan_idx key
  for chan in "${FAN_CHANNELS[@]}"; do
    hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
    fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
    key="$(fan_curve_key "${hw_idx}" "${fan_idx}")"
    printf '\n#CURVE_MIN_%s="%s"\n#CURVE_MID_%s="%s"\n#CURVE_MAX_%s="%s"' \
      "${key}" "${CURVE_MIN}" "${key}" "${CURVE_MID}" "${key}" "${CURVE_MAX}"
  done
}

# Echo the first discovered fan's key, as a sample value for the FAN_EXCLUDE example
# line in the first-boot task template written by update_task().
fan_exclude_example() {
  [ "${#FAN_CHANNELS[@]}" -eq 0 ] && return
  local chan="${FAN_CHANNELS[0]}" hw_idx fan_idx
  hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
  fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
  fan_curve_key "${hw_idx}" "${fan_idx}"
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

# Discover hwmon fans with RPM > 0 and a matching writable pwm channel, skipping any
# listed in FAN_EXCLUDE (identified by fan_curve_key()). Populates FAN_CHANNELS array.
# Requires FAN_EXCLUDE to already be loaded (call load_task first).
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
      fan_is_excluded "$(fan_curve_key "${IDX}" "${FNUM}")" && continue
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

# Compute MINTEMP/MIDTEMP/MAXTEMP + PWM_MIN/MID/MAX (0-255) for one fan at the given mode
# index, honoring that fan's CURVE_*_<key> override if set. Results are echoed as a single
# "MINTEMP MIDTEMP MAXTEMP PWM_MIN PWM_MID PWM_MAX" line for the caller to read into vars.
# $1: mode index (0=fullfan, 1=coolfan, 2=quietfan), $2: fan curve key (chip_pwmN)
fan_mode_curve() {
  local MIDX="${1}" key="${2}"
  local mn mid mx
  IFS='|' read -r mn mid mx <<<"$(curve_for_fan_key "${key}")"

  local FANMODES_LOCAL
  derive_curve_vars "${mn}" "${mx}"
  FANMODES_LOCAL=("${FANMODES[@]}")

  local FANMODE="${FANMODES_LOCAL[${MIDX}]}"
  local MINTEMP MIDTEMP MAXTEMP
  local _tempcol=$(( MIDX * 2 + 1 ))
  MINTEMP="$(echo "${FANMODE}" | cut -d' ' -f1)"
  MAXTEMP="$(echo "${FANMODE}" | cut -d' ' -f2)"
  MIDTEMP="$(echo "${mid}" | awk "{print \$${_tempcol}}")"

  local _pwmcol=$(( MIDX * 2 + 2 ))
  local P_MIN P_MID P_MAX
  P_MIN="$(echo "${mn}" | awk "{print \$${_pwmcol}}")"
  P_MID="$(echo "${mid}" | awk "{print \$${_pwmcol}}")"
  P_MAX="$(echo "${mx}" | awk "{print \$${_pwmcol}}")"

  echo "${MINTEMP} ${MIDTEMP} ${MAXTEMP} $(percent_to_pwm "${P_MIN}") $(percent_to_pwm "${P_MID}") $(percent_to_pwm "${P_MAX}")"
}

# Generate /etc/fan2go/fan2go.yaml from FAN_CHANNELS + active mode index, using each fan's
# own curve (CURVE_*_<key> override if set, else the global CURVE_MIN/MID/MAX).
# $1: mode index (0=fullfan, 1=coolfan, 2=quietfan)
generate_fan2go_config() {
  local MIDX="${1:-1}"
  [ "${#FANMODES[@]}" -eq 0 ] && derive_curve_vars

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
      local hw_idx fan_idx platform fan_id key
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      platform="$(hwmon_platform "${hw_idx}")"
      fan_id="fan_${hw_idx}_${fan_idx}"
      key="$(fan_curve_key "${hw_idx}" "${fan_idx}")"

      local _fan_pwm_min
      read -r _ _ _ _fan_pwm_min _ _ <<<"$(fan_mode_curve "${MIDX}" "${key}")"

      local min_pwm=1
      local start_pwm="${FAN_LEARNED_START[${fan_id}]:-}"
      if [ -n "${start_pwm}" ] && [ "${start_pwm}" -ge 30 ] 2>/dev/null; then
        min_pwm="${start_pwm}"
      fi
      local curve_min="${_fan_pwm_min}"
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
      local hw_idx fan_idx key
      hw_idx="$(echo "${chan}" | sed 's/hwmon\([0-9]*\)\/.*/\1/')"
      fan_idx="$(echo "${chan}" | sed 's/.*pwm\([0-9]*\)/\1/')"
      key="$(fan_curve_key "${hw_idx}" "${fan_idx}")"

      local _mintemp _midtemp _maxtemp _pwm_min _pwm_mid _pwm_max
      read -r _mintemp _midtemp _maxtemp _pwm_min _pwm_mid _pwm_max <<<"$(fan_mode_curve "${MIDX}" "${key}")"

      local fan_id="fan_${hw_idx}_${fan_idx}"
      local start_pwm="${FAN_LEARNED_START[${fan_id}]:-}"
      local curve_min="${_pwm_min}"
      if [ -n "${start_pwm}" ] && [ "${start_pwm}" -ge 30 ] 2>/dev/null && [ "${curve_min}" -lt "${start_pwm}" ] 2>/dev/null; then
        curve_min="${start_pwm}"
      fi

      cat <<YAML
  - id: "curve_${hw_idx}_${fan_idx}"
    linear:
      sensor: cpu_temp
      steps:
        ${_mintemp}: ${curve_min}
        ${_midtemp}: ${_pwm_mid}
        ${_maxtemp}: ${_pwm_max}
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

# Restore pwm*_enable to its pre-manual-mode value for any fan that is now listed in
# FAN_EXCLUDE, handing it back to BIOS/hardware automatic control, and forget it so
# cleanup() no longer touches it. Call after load_task on reload (FAN_EXCLUDE must be current).
restore_excluded_pwm_enable() {
  local PWM_ENABLE
  for PWM_ENABLE in "${!PWM_ENABLE_ORIG[@]}"; do
    [[ "${PWM_ENABLE}" =~ hwmon([0-9]+)/pwm([0-9]+)_enable$ ]] || continue
    fan_is_excluded "$(fan_curve_key "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")" || continue
    [ -w "${PWM_ENABLE}" ] && echo "${PWM_ENABLE_ORIG[${PWM_ENABLE}]}" >"${PWM_ENABLE}" 2>/dev/null
    unset "PWM_ENABLE_ORIG[${PWM_ENABLE}]"
  done
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

  # Load FAN_EXCLUDE (+ curves) before touching pwm*_enable so excluded fans are left
  # entirely under BIOS/hardware automatic control.
  load_task

  # Save original pwm*_enable values and switch to manual mode so pwm* nodes become writable
  for PWM_ENABLE in /sys/class/hwmon/hwmon*/pwm*_enable; do
    [[ "${PWM_ENABLE}" =~ hwmon([0-9]+)/pwm([0-9]+)_enable$ ]] || continue
    local _hw_idx="${BASH_REMATCH[1]}" _fan_idx="${BASH_REMATCH[2]}"
    fan_is_excluded "$(fan_curve_key "${_hw_idx}" "${_fan_idx}")" && continue
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
    coolfan | high)  echo "1" ;;
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
      restore_excluded_pwm_enable
      discover_fans
      save_fan_channels
      generate_fan2go_config "${FanBaseMode:-1}"
      restart_fan2go
      continue
    fi

    # Mode change: read synoinfo.conf every tick (no mtime gate - DSM may
    # write it via a temp-file-then-rename dance, and gating on mtime risks
    # permanently missing an update if the gate's mtime snapshot races it).
    local FanCurtMode
    FanCurtMode="$(fantype_to_mode)"

    if [ "${FanCurtMode}" != "${FanBaseMode}" ]; then
      echo "Fan mode changed to ${FanCurtMode}"
      FanBaseMode="${FanCurtMode}"
      load_task
      generate_fan2go_config "${FanBaseMode}"
      restart_fan2go
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
