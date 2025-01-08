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
  if ! lsmod | grep -q "cpufreq_${GOVERNOR}"; then
    if [ -f "/usr/lib/modules/cpufreq_${GOVERNOR}.ko" ]; then
      insmod /usr/lib/modules/cpufreq_${GOVERNOR}.ko
    else
      echo "CPUFreqScaling: Governor module cpufreq_${GOVERNOR}.ko not found"
    fi
  fi
  if lsmod | grep -q "cpufreq_${GOVERNOR}"; then
    # Set correct cpufreq governor to allow frequency scaling
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    sleep 5
    # Check if the governor is set correctly
    SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
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
[ "${cerror}" = "true" ] && exit 1 || exit 0