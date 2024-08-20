#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Make things safer
set -euo pipefail

# Get cpu cores count minus 1, to allow maping from 0
cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
cpucorecount=$((cpucorecount - 1))
error=0

# Load the correct cpufreq module
if [ "${1}" = "ondemand" ] || [ "${1}" = "conservative" ]; then
  if [ -f "/usr/lib/modules/cpufreq_${1}.ko" ]; then
    modprobe cpufreq_${1}
    echo "CPUFreqScaling: cpufreq_${1} loaded"
  else
    echo "CPUFreqScaling: cpufreq_${1} not found"
    error=1
  fi
fi
# Deamonize the main function...
for i in $(seq 0 ${cpucorecount}); do
  governor=$(cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor)
  # Set correct cpufreq governor to allow frequency scaling
  if [ "${governor}" != "${1}" ]; then
    echo "${1}" >/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor
  fi
done
sleep 10
# Check if the governor is set correctly
for i in $(seq 0 ${cpucorecount}); do
  governor=$(cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor)
  if [ "${governor}" = "${1}" ]; then
    echo "CPUFreqScaling: Governor set to ${1}"
  else
    echo "CPUFreqScaling: Failed to set governor to ${1}"
    error=1
  fi
done
[ "${error}" -eq 1 ] && exit 1
exit 0