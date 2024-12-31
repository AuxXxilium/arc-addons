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
if lsmod | grep -q acpi_cpufreq || modprobe acpi_cpufreq; then
  GOVERNOR=$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)
  SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
  if [ "${GOVERNOR}" = "ondemand" ] || [ "${GOVERNOR}" = "conservative" ]; then
    insmod "/usr/lib/modules/cpufreq_${GOVERNOR}.ko" || cerror=1
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
else
  echo "CPUFreqScaling: acpi_cpufreq module could not be loaded"
fi
[ ${cerror} -eq 1 ] && exit 1 || exit 0