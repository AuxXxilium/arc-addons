#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Load the correct cpufreq module
SCALINGRETRY=0
SCALINGERROR=0
touch "/tmp/scaling.log"
[ -f "/tmp/scaling.count" ] && SCALINGRETRY=$(cat /tmp/scaling.count) || echo "${SCALINGRETRY}" > "/tmp/scaling.count"
[ -n "${1}" ] && GOVERNOR=${1} || GOVERNOR=$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)
SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${GOVERNOR}" = "ondemand" ] || [ "${GOVERNOR}" = "conservative" ]; then
  insmod "/usr/lib/modules/cpufreq_${GOVERNOR}.ko"  >> /tmp/scaling.log || SCALINGERROR=1
fi
# Set correct cpufreq governor to allow frequency scaling
if [ "${SYSGOVERNOR}" != "${GOVERNOR}" ] && [ ${SCALINGERROR} -eq 0 ]; then
  echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >> "/tmp/scaling.log"
  sleep 10
fi
# Check if the governor is set correctly
SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
  echo "CPUFreqScaling: Governor set to ${GOVERNOR}" >> "/tmp/scaling.log"
else
  echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR}" >> "/tmp/scaling.log"
  SCALINGERROR=1
fi
if [ ${SCALINGERROR} -eq 1 ] && [ ${SCALINGRETRY} -lt 3 ]; then
  echo "$((${SCALINGRETRY} + 1))" > "/tmp/scaling.count"
  exit 1
else
  exit 0
fi