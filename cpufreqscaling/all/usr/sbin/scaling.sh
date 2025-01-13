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
SCALINGCOUNT=0
touch /tmp/scaling.log
[ -f /tmp/scaling.count ] && SCALINGCOUNT=$(cat /tmp/scaling.count) || echo "${SCALINGCOUNT}" > /tmp/scaling.count
GOVERNOR=$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)
SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${SYSGOVERNOR}" != "${GOVERNOR}" ]; then
  if [[ "${GOVERNOR}" = "ondemand" || "${GOVERNOR}" = "conservative" ]] && ! lsmod | grep -q "${GOVERNOR}"; then
    if modprobe "cpufreq_${GOVERNOR}"; then
      echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
      sleep 10
    else
      echo "CPUFreqScaling: Failed to load ${GOVERNOR} module" >> /tmp/scaling.log
    fi
  elif [ "${GOVERNOR}" = "schedutil" ] || lsmod | grep -q "${GOVERNOR}"; then
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    sleep 10
  fi
  # Check if the governor is set correctly
  SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
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
  echo "$((${SCALINGCOUNT} + 1))" > /tmp/scaling.count
  exit 1
fi