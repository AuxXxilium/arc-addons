#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set_governor() {
  echo "CPUFreqScaling: Setting governor to ${GOVERNOR}"
  scaling_files=()
  for cpu in /sys/devices/system/cpu/cpu*; do
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
  for cpu in /sys/devices/system/cpu/cpu*; do
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

if [ "${GOVERNOR}" != "schedutil" ]; then
  ALL_GOVERNORS=("ondemand" "conservative" "userspace" "powersave" "performance" "interactive")
  REQUIRED_MODULES=("cpufreq_stats" "cpufreq_governor")
  for GOV in "${ALL_GOVERNORS[@]}"; do
    REQUIRED_MODULES+=("cpufreq_${GOV}")
  done

  for MODULE in "${REQUIRED_MODULES[@]}"; do
    if ! lsmod | grep -qw "${MODULE}"; then
      MODULE_PATH="/usr/lib/modules/${MODULE}.ko"
      if [ -f "${MODULE_PATH}" ]; then
        insmod "${MODULE_PATH}" 2>/dev/null || true
      fi
    fi
  done

  # if requested governor is not available after loading, fall back to ondemand
  AVAIL_GOV_FILE=""
  for cpu in /sys/devices/system/cpu/cpu*; do
    [ -f "${cpu}/cpufreq/scaling_available_governors" ] && AVAIL_GOV_FILE="${cpu}/cpufreq/scaling_available_governors" && break
  done
  if [ -n "${AVAIL_GOV_FILE}" ] && ! grep -qw "${GOVERNOR}" "${AVAIL_GOV_FILE}" 2>/dev/null; then
    echo "CPUFreqScaling: ${GOVERNOR} governor not available, falling back to ondemand"
    GOVERNOR="ondemand"
  fi
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
  kill -9 "$(ps aux 2>/dev/null | grep -F "scaling.sh" | grep -v grep | awk '{print $2}' | head -1)" 2>/dev/null || true
  exit 1
fi