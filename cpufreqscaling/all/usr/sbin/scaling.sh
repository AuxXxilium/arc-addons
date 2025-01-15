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

if [ ${SCALINGCOUNT} -gt 3 ]; then
  echo "CPUFreqScaling: Failed to set governor to ${GOVERNOR} after ${SCALINGCOUNT} retries" >> /tmp/scaling.log
  exit 0
fi

if [ "${SYSGOVERNOR}" != "${GOVERNOR}" ]; then
  case "${GOVERNOR}" in
    ondemand|conservative)
      insmod "/usr/lib/modules/cpufreq_${GOVERNOR}.ko" 2>/dev/null || true
      echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
      ;;
    schedutil|powersave)
      echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
      ;;
  esac
  sleep 3
  SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
    echo "CPUFreqScaling: governor set to ${GOVERNOR}" >> /tmp/scaling.log
  else
    echo "CPUFreqScaling: failed to set governor to ${GOVERNOR}" >> /tmp/scaling.log
    exit 1
  fi

  sleep 17
  echo "CPUFreqScaling: ReChecking governor" >> /tmp/scaling.log

  SYSGOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  if [ "${SYSGOVERNOR}" = "${GOVERNOR}" ]; then
    echo "CPUFreqScaling: governor set to ${GOVERNOR}" >> /tmp/scaling.log
    exit 0
  else
    echo "CPUFreqScaling: failed to set governor to ${GOVERNOR}" >> /tmp/scaling.log
  fi
fi
exit 1