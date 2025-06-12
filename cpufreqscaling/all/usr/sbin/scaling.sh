#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set_governor() {
  echo "CPUFreqScaling: Setting governor to ${GOVERNOR}"

  if [ -z "${GOVERNOR}" ]; then
    echo "CPUFreqScaling: No governor specified, exiting"
    exit 1
  fi

  scaling_files=()
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    if [ -d "${cpu}/cpufreq" ]; then
      scaling_files+=("${cpu}/cpufreq/scaling_governor")
    fi
  done

  if [ "${#scaling_files[@]}" -gt 0 ]; then
    echo "${GOVERNOR}" | tee "${scaling_files[@]}" > /dev/null
    echo "CPUFreqScaling: Governor set to ${GOVERNOR} for all CPUs"
  else
    echo "CPUFreqScaling: No CPUs with cpufreq support found"
  fi
}

all_cpus_set() {
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    if [ -d "${cpu}/cpufreq" ]; then
      current_gov=$(cat "${cpu}/cpufreq/scaling_governor" 2>/dev/null)
      [ "${current_gov}" != "${GOVERNOR}" ] && return 1
    fi
  done
  return 0
}

main() {
  echo "CPUFreqScaling: Starting CPU frequency scaling setup"

  if [ "${GOVERNOR}" != "schedutil" ] && ! lsmod | grep -qw "cpufreq_${GOVERNOR}"; then
        insmod "/usr/lib/modules/cpufreq_${GOVERNOR}.ko" || {
        echo "CPUFreqScaling: Failed to load cpufreq module for ${GOVERNOR}, exiting"
        exit 1
      }
  fi

  while ! all_cpus_set; do
    set_governor
    sleep 10
  done

  echo "CPUFreqScaling: All CPUs set to ${GOVERNOR}, exiting."
}

# Load governor from kernel cmdline
GOVERNOR="$(grep -o 'governor=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"

main &