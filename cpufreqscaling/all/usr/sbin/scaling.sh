#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Make things safer
set -euo pipefail

# Load the correct cpufreq module
touch /tmp/scaling.log
SCALINGCOUNT=$(cat /tmp/scaling.count 2>/dev/null || echo 0)
GOVERNOR="$(grep -o 'governor=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"
SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"

if [ "${SYSGOVERNOR}" != "${GOVERNOR}" ]; then
  if [[ "${GOVERNOR}" = "ondemand" || "${GOVERNOR}" = "conservative" ]]; then
    if /usr/sbin/modprobe "cpufreq_${GOVERNOR}"; then
      echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    else
      echo "CPUFreqScaling: Failed to load ${GOVERNOR} module" >> /tmp/scaling.log
    fi
  elif [[ "${GOVERNOR}" = "schedutil" || "${GOVERNOR}" = "powersave" ]]; then
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  fi

  sleep 10
  SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
    echo "CPUFreqScaling: Governor set to ${GOVERNOR}" >> /tmp/scaling.log
    exit 0
  else
    echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR}" >> /tmp/scaling.log
  fi
fi

if [ ${SCALINGCOUNT} -gt 3 ]; then
  echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR} after ${SCALINGCOUNT} retries" >> /tmp/scaling.log
  exit 0
else
  echo $((SCALINGCOUNT + 1)) > /tmp/scaling.count
  exit 1
fi