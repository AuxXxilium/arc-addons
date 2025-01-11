#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Load the correct cpufreq module
cerror=0
[ -n "${1}" ] && GOVERNOR=${1} || GOVERNOR=$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)
SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${GOVERNOR}" = "ondemand" ] || [ "${GOVERNOR}" = "conservative" ]; then
  modprobe -d "/usr/lib/modules" cpufreq_${GOVERNOR} || cerror=1
fi
# Set correct cpufreq governor to allow frequency scaling
if [ "${SYSGOVERNOR}" != "${GOVERNOR}" ]; then
  echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi
sleep 10
# Check if the governor is set correctly
SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
  echo "CPUFreqScaling: Governor set to ${GOVERNOR}"
else
  echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR}"
  cerror=1
fi
[ ${cerror} -eq 1 ] && exit 1 || exit 0