#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set_governor() {
  echo "CPUFreqScaling: Setting governor to ${GOVERNOR}"
  scaling_files=()
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -d "${cpu}/cpufreq" ] && scaling_files+=("${cpu}/cpufreq/scaling_governor")
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
    [ -d "${cpu}/cpufreq" ] && [ "$(cat "${cpu}/cpufreq/scaling_governor" 2>/dev/null)" != "${GOVERNOR}" ] && return 1
  done
  return 0
}

echo "CPUFreqScaling: Starting CPU frequency scaling setup"
GOVERNOR="$(grep -o 'governor=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"

if [ -z "${GOVERNOR}" ]; then
  echo "CPUFreqScaling: No governor specified, exiting"
  exit 1
fi

if [ "${GOVERNOR}" != "schedutil" ] && ! lsmod | grep -qw "cpufreq_${GOVERNOR}"; then
  insmod "/usr/lib/modules/cpufreq_governor.ko" 2>/dev/null || true
  insmod "/usr/lib/modules/cpufreq_${GOVERNOR}.ko" 2>/dev/null || true
fi

for i in {1..3}; do
  all_cpus_set && break
  set_governor
  sleep 10
done

if all_cpus_set; then
  echo "CPUFreqScaling: All CPUs set to ${GOVERNOR}, exiting."
else
  echo "CPUFreqScaling: Failed to set all CPUs after 3 tries, exiting."
  pkill -f "scaling.sh" || true
  exit 1
fi