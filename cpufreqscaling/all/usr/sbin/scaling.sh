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
cerror="false"
if grep -qv "^flags.*hypervisor.*" /proc/cpuinfo; then
  GOVERNOR="$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)"
  SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  if insmod /usr/lib/modules/cpufreq_${GOVERNOR}.ko; then
    # Set correct cpufreq governor to allow frequency scaling
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    sleep 5
    # Check if the governor is set correctly
    SYSGOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
      echo "CPUFreqScaling: Governor set to ${GOVERNOR}"
    else
      echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR}"
      cerror="true"
    fi
  else
    echo "CPUFreqScaling: Failed to load cpufreq_${GOVERNOR}.ko"
    cerror="true"
  fi
fi
if [ "${cerror}" = "true" ]; then
  exit 1
else
  exit 0
fi