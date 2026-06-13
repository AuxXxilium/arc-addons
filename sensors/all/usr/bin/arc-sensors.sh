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
# MINPWM and MAXPWM are in percent (0–100)

apply_amd_tctl_offset() {
  local offset=0 conf="/etc/sensors.d/k10temp-tdie.conf"
  grep -q 'AuthenticAMD' /proc/cpuinfo 2>/dev/null || return

  # Check the CUR_TEMP SMN register for the TJ_SEL==3 && RANGE_SEL==0 condition.
  # Uses raw PCI config space via sysfs (always available, no tools required).
  local hwmon_path pci_config
  hwmon_path="$(find /sys/class/hwmon -name 'name' -exec grep -lx 'k10temp' {} \; 2>/dev/null | head -1)"
  pci_config="$(readlink -f "$(dirname "${hwmon_path}")/device" 2>/dev/null)/config"
  if [ -w "${pci_config}" ] && [ -r "${pci_config}" ]; then
    # Write SMN address 0x00059800 to register B8h (4 bytes, little-endian)
    printf '\x00\x98\x05\x00' | dd of="${pci_config}" bs=1 seek=184 count=4 conv=notrunc 2>/dev/null
    # Read result from register BCh (4 bytes, reassemble little-endian in shell)
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
    printf 'chip "k10temp-*"\n    compute temp1 @+(%d), @-(%d)\n' "${offset}" "${offset}" > "${conf}"
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
  local PERCENT=$1
  local FAN="hwmon${I}/fan${IDX}_input"
  local PWM="hwmon${I}/pwm${IDX}"
  [ "${PERCENT}" -lt 0 ] && PERCENT=0
  [ "${PERCENT}" -gt 100 ] && PERCENT=100
  local PWM_FILE="/etc/pwm.conf"
  if [ ! -f "${PWM_FILE}" ]; then
    echo $(( PERCENT * 255 / 100 ))
  else
    local MAX_RPM
    MAX_RPM=$(awk -v fan="$FAN" -v pwm="$PWM" '$1==fan && $3==pwm {if($2>m)m=$2} END{print m+0}' "${PWM_FILE}")
    [ "$MAX_RPM" -eq 0 ] && echo $(( PERCENT * 255 / 100 )) && return
    local TARGET_RPM=$(( MAX_RPM * PERCENT / 100 ))
    awk -v fan="$FAN" -v pwm="$PWM" -v target="$TARGET_RPM" '
        $1==fan && $3==pwm {
            diff = ($2-target); if(diff<0) diff=-diff;
            if(min=="" || diff<min) { min=diff; best=$4 }
        }
        END { if(best!="") print best; else print int(target/10)*10 }
    ' "${PWM_FILE}"
  fi
}

generate_fancontrol_config() {
  local OPERATION FANMODE M=${1:-0}
  local FANMODES=("${DEFMODES[@]}")
  OPERATION="$(synowebapi -s --exec api=SYNO.Core.EventScheduler method=get task_name=\"Fancontrol\" | jq -r '.data.operation' 2>/dev/null)"
  eval "${OPERATION}" >/dev/null 2>&1 || true
  [[ ${FANMODES[${M}]} =~ ^([0-9]+)\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)$ ]] && FANMODE="${FANMODES[${M}]}" || FANMODE="${DEFMODES[${M}]}"

  local DEVPATH DEVNAME FCTEMPS FCFANS MINTEMP MAXTEMP MINSTART MINSTOP MINPWM MAXPWM

  CORETEMP="$(find "/sys/devices/platform/" -name "temp1_input" | grep -E 'coretemp|k10temp' | head -1 | sed -n 's|.*/\(hwmon.*\/temp1_input\).*|\1|p')"
  for P in $(find "/sys/devices/platform/" -type f -name "temp1_input"); do
    D="$(echo "${P}" | sed -n 's|.*/\(devices/platform/[^/]*\)/.*|\1|p')"
    I="$(echo "${P}" | sed -n 's|.*hwmon\([0-9]\).*|\1|p')"
    DEVPATH="${DEVPATH} hwmon${I}=${D}"
    DEVNAME="${DEVNAME} hwmon${I}=$(cat /sys/${D}/*/*/name)"
    for F in $(find "/sys/${D}" -type f -name "fan[0-9]_input"); do
      R="$(cat "${F}" 2>/dev/null)"
      [ "${R:-0}" -le 0 ] && continue
      IDX="$(echo "${F}" | sed -n 's|.*fan\([0-9]\)_input|\1|p')"
      FCTEMPS="${FCTEMPS} hwmon${I}/pwm${IDX}=${CORETEMP}"
      FCFANS="${FCFANS} hwmon${I}/pwm${IDX}=hwmon${I}/fan${IDX}_input"
      MINTEMP="${MINTEMP} hwmon${I}/pwm${IDX}=$(echo "${FANMODE}" | cut -d' ' -f1)"
      MAXTEMP="${MAXTEMP} hwmon${I}/pwm${IDX}=$(echo "${FANMODE}" | cut -d' ' -f2)"
      MINPWMP="$(percent_to_pwm $(echo "${FANMODE}" | cut -d' ' -f3))"
      MAXPWMP="$(percent_to_pwm $(echo "${FANMODE}" | cut -d' ' -f4))"
      [ "${MAXPWMP}" -le "${MINPWMP}" ] && MAXPWMP="$((MINPWMP + 10))"
      MINSTART="${MINSTART} hwmon${I}/pwm${IDX}=${MINPWMP}"
      MINSTOP="${MINSTOP} hwmon${I}/pwm${IDX}=${MINPWMP}"
      MINPWM="${MINPWM} hwmon${I}/pwm${IDX}=${MINPWMP}"
      MAXPWM="${MAXPWM} hwmon${I}/pwm${IDX}=${MAXPWMP}"
    done
  done

  DEST="/etc/fancontrol"
  rm -f "${DEST}"
  {
    echo "# Configuration file generated by pwmconfig, changes will be lost"
    echo "INTERVAL=10"
    echo "DEVPATH=$(echo ${DEVPATH})"
    echo "DEVNAME=$(echo ${DEVNAME})"
    echo "FCTEMPS=$(echo ${FCTEMPS})"
    echo "FCFANS=$(echo ${FCFANS})"
    echo "MINTEMP=$(echo ${MINTEMP})"
    echo "MAXTEMP=$(echo ${MAXTEMP})"
    echo "MINSTART=$(echo ${MINSTART})"
    echo "MINSTOP=$(echo ${MINSTOP})"
    echo "MINPWM=$(echo ${MINPWM})"
    echo "MAXPWM=$(echo ${MAXPWM})"
  } >"${DEST}"
}

main() {
apply_amd_tctl_offset

if [ -z "$(find /sys/ -name "fan*_input")" ]; then
  echo "No fan detected, exiting..."
  set_fan_conf "no"
  exit 0
fi

set_fan_conf "yes"

for PWM_ENABLE in /sys/class/hwmon/hwmon*/pwm*_enable; do
  if [[ "${PWM_ENABLE}" =~ pwm([0-9]+)_enable$ ]] && [ -w "${PWM_ENABLE}" ]; then
    echo 1 > "${PWM_ENABLE}"
  fi
done

FanBaseMode=""
while true; do
  sleep 1
  FanType="$(/bin/get_key_value /etc/synoinfo.conf fan_config_type_internal 2>/dev/null)"
  case "${FanType}" in
    fullfan | full) FanCurtMode="0" ;;
    coolfan | high) FanCurtMode="1" ;;
    quietfan | low) FanCurtMode="2" ;;
    *) FanCurtMode="1" ;;
  esac
  if echo "0 1 2" | grep -wq "${FanCurtMode}"; then
    if [ "${FanCurtMode}" != "${FanBaseMode}" ]; then
      echo "Fan speed mode changed to ${FanCurtMode}"
      FanBaseMode="${FanCurtMode}"
      if [ 0 = "${FanBaseMode}" ] && [ -f "/etc/fancontrol.full" ]; then
        cp -f "/etc/fancontrol.full" "/etc/fancontrol"
      elif [ 1 = "${FanBaseMode}" ] && [ -f "/etc/fancontrol.high" ]; then
        cp -f "/etc/fancontrol.high" "/etc/fancontrol"
      elif [ 2 = "${FanBaseMode}" ] && [ -f "/etc/fancontrol.low" ]; then
        cp -f "/etc/fancontrol.low" "/etc/fancontrol"
      else
        generate_fancontrol_config "${FanBaseMode}"
      fi
      /usr/bin/pkill -f "/usr/sbin/fancontrol" 2>/dev/null
      for _w in 1 2 3 4 5; do
        ps aux 2>/dev/null | grep -v grep | grep -q "/usr/sbin/fancontrol" || break
        sleep 1
      done
      rm -f "/run/fancontrol.pid" "/var/run/fancontrol.pid" 2>/dev/null
      /usr/sbin/fancontrol 2>/dev/null &
    fi
  fi
  find /etc -maxdepth 1 -type f -name 'synoinfo.conf.??????' -mmin +0.5 -exec rm -f {} \; 2>/dev/null
done
}

trap '/usr/bin/pkill -f "/usr/sbin/fancontrol" 2>/dev/null; rm -f "/run/fancontrol.pid" "/var/run/fancontrol.pid" 2>/dev/null' EXIT INT TERM HUP
main &