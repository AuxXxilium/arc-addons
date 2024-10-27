#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Make things safer
set -euo pipefail

# Load the correct cpufreq module
cerror=0
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${1}" == "ondemand" ] || [ "${1}" == "conservative" ]; then
  insmod /usr/lib/modules/cpufreq_${1}.ko || cerror=1
fi
# Set correct cpufreq governor to allow frequency scaling
if [ "${governor}" != "${1}" ]; then
  echo "${1}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi
sleep 10
# Check if the governor is set correctly
verifygovernor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "${verifygovernor}" == "${1}" ]; then
  echo "CPUFreqScaling: Governor set to ${1}"
else
  echo "CPUFreqScaling: Failed to set governor to ${1}"
  cerror=1
fi
[ ${cerror} -eq 1 ] && exit 1 || exit 0