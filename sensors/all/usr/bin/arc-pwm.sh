#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Sweeps all PWM/fan pairs to find the minimum PWM at which each fan spins.
# Results are written back into the esynoscheduler Fancontrol task as
# per-fan minPWM defaults, then arc-sensors.sh is restarted to apply them.
#

STEP=5
DELAY=2
FAN2GO_BIN="/usr/sbin/fan2go"
ESYNOSCHEDULER_DB="/usr/syno/etc/esynoscheduler/esynoscheduler.db"

# Stop fan2go before sweep
for ((count=0; count<5; count++)); do
  pkill -0 -f "${FAN2GO_BIN}" 2>/dev/null || break
  pkill -f "${FAN2GO_BIN}" 2>/dev/null
  sleep 0.5
done

# Load current task variables (FANMODES, FAN_CURVES)
FANMODES=()
FAN_CURVES=()
if [ -f "${ESYNOSCHEDULER_DB}" ]; then
  OP="$(synowebapi -s --exec api=SYNO.Core.EventScheduler method=get task_name=\"Fancontrol\" 2>/dev/null | jq -r '.data.operation' 2>/dev/null)"
  [ -n "${OP}" ] && eval "${OP}" 2>/dev/null || true
fi
[ "${#FANMODES[@]}" -eq 0 ] && FANMODES=("20 50 50 100" "20 60 20 60" "20 70 10 50")

# Index existing FAN_CURVES by channel
declare -A existing_curves=()
for entry in "${FAN_CURVES[@]}"; do
  existing_curves["${entry%%:*}"]="${entry#*:}"
done

echo "Starting PWM sweep..."

declare -A fan_min_pwm=()

for HW in /sys/class/hwmon/hwmon*; do
  HW_IDX="$(basename "${HW}" | sed 's/hwmon//')"
  for PWM in "${HW}"/pwm[0-9]*; do
    [ -w "${PWM}" ] || continue
    [[ "$(basename "${PWM}")" =~ ^pwm([0-9]+)$ ]] || continue
    FNUM="${BASH_REMATCH[1]}"
    FAN="${HW}/fan${FNUM}_input"
    [ -r "${FAN}" ] || continue
    RPM="$(cat "${FAN}" 2>/dev/null)"
    [ "${RPM:-0}" -le 0 ] && continue

    CHAN="hwmon${HW_IDX}/pwm${FNUM}"
    echo "Sweeping ${CHAN}..."

    # Save state
    OLD_ENABLE="$(cat "${PWM}_enable" 2>/dev/null)"
    OLD_PWM="$(cat "${PWM}" 2>/dev/null)"
    echo 1 >"${PWM}_enable" 2>/dev/null

    # Ramp up from 0 to find start PWM
    MIN_SPIN=255
    echo 0 >"${PWM}"
    sleep ${DELAY}
    for ((val=0; val<=255; val+=STEP)); do
      echo ${val} >"${PWM}"
      sleep ${DELAY}
      RPM="$(cat "${FAN}" 2>/dev/null)"
      if [ "${RPM:-0}" -gt 0 ]; then
        MIN_SPIN=${val}
        echo "  ${CHAN}: fan starts at PWM ${val} (${RPM} RPM)"
        break
      fi
    done

    # Convert min spin PWM to percent (round up to nearest 5%)
    MIN_P=$(( (MIN_SPIN * 100 / 255 + 4) / 5 * 5 ))
    [ "${MIN_P}" -lt 5 ] && MIN_P=5
    fan_min_pwm["${CHAN}"]="${MIN_P}"
    echo "  ${CHAN}: min PWM ~${MIN_P}%"

    # Restore
    echo "${OLD_PWM}" >"${PWM}" 2>/dev/null
    [ -n "${OLD_ENABLE}" ] && echo "${OLD_ENABLE}" >"${PWM}_enable" 2>/dev/null
  done
done

echo "Sweep complete. Updating task..."

# Merge sweep results into FAN_CURVES:
# For each channel, keep existing maxPWM values per mode but update minPWM
# to the measured value (applied to all 3 modes).
NEW_FAN_CURVES=()
for CHAN in "${!fan_min_pwm[@]}"; do
  MIN_P="${fan_min_pwm[${CHAN}]}"
  if [ -n "${existing_curves[${CHAN}]}" ]; then
    # Parse existing: "full_min full_max:cool_min cool_max:quiet_min quiet_max"
    local_vals="${existing_curves[${CHAN}]}"
    f1="$(echo "${local_vals}" | cut -d: -f1)"
    f2="$(echo "${local_vals}" | cut -d: -f2)"
    f3="$(echo "${local_vals}" | cut -d: -f3)"
    # Keep user maxPWM, replace minPWM with measured value
    f1_max="$(echo "${f1}" | cut -d' ' -f2)"
    f2_max="$(echo "${f2}" | cut -d' ' -f2)"
    f3_max="$(echo "${f3}" | cut -d' ' -f2)"
    [ "${f1_max:-0}" -le "${MIN_P}" ] && f1_max=$(( MIN_P + 10 ))
    [ "${f2_max:-0}" -le "${MIN_P}" ] && f2_max=$(( MIN_P + 10 ))
    [ "${f3_max:-0}" -le "${MIN_P}" ] && f3_max=$(( MIN_P + 10 ))
    NEW_FAN_CURVES+=("${CHAN}:${MIN_P} ${f1_max}:${MIN_P} ${f2_max}:${MIN_P} ${f3_max}")
  else
    # New channel: set min to measured, max to sensible defaults per mode
    NEW_FAN_CURVES+=("${CHAN}:${MIN_P} 100:${MIN_P} 60:${MIN_P} 50")
  fi
done

# Also keep any existing entries for channels we didn't sweep (no fan spinning)
for entry in "${FAN_CURVES[@]}"; do
  CHAN="${entry%%:*}"
  [ -n "${fan_min_pwm[${CHAN}]}" ] || NEW_FAN_CURVES+=("${entry}")
done

# Write back to task
DEF_FANMODES_STR="\"${FANMODES[0]}\" \"${FANMODES[1]}\" \"${FANMODES[2]}\""
curves_str="FAN_CURVES=("$'\n'
for entry in "${NEW_FAN_CURVES[@]}"; do
  curves_str+="  \"${entry}\""$'\n'
done
curves_str+=")"

operation='# Fan modes: MINTEMP MAXTEMP (shared across fans)
#                       fullfan             coolfan               quietfan
#                          |                      |                        |
FANMODES=('"${DEF_FANMODES_STR}"')

# Per-fan PWM% per mode: "hwmonX/pwmY:full_min full_max:cool_min cool_max:quiet_min quiet_max"
# minPWM values were auto-measured by arc-pwm.sh sweep.
'"${curves_str}"

sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
INSERT INTO task VALUES('Fancontrol', '', 'bootup', '', 0, 0, 0, 0, '', 0, '$(printf '%s' "${operation}" | sed "s/'/''/g")', 'script', '{}', '', '', '{}', '{}');
EOF

echo "Task updated. Restarting arc-sensors.sh..."
pkill -f "/usr/bin/arc-sensors.sh" 2>/dev/null
sleep 1
/usr/bin/arc-sensors.sh >/dev/null 2>&1 &
echo "Done."
