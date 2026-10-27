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
  # No cpufreq policy yet is not "set": without the count this passed over
  # an empty set, and the governor was never written.
  found=0
  for cpu in /sys/devices/system/cpu/cpu*; do
    [ -d "${cpu}/cpufreq" ] || continue
    found=$((found + 1))
    [ "$(cat "${cpu}/cpufreq/scaling_governor" 2>/dev/null)" != "${GOVERNOR}" ] && return 1
  done
  [ "${found}" -gt 0 ]
}

echo "CPUFreqScaling: Starting CPU frequency scaling setup"
GOVERNOR="$(grep -o 'governor=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"

if [ -z "${GOVERNOR}" ]; then
  echo "CPUFreqScaling: No governor specified, exiting"
  exit 1
fi

if [ "${GOVERNOR}" != "schedutil" ]; then
  REQUIRED_MODULES=("cpufreq_stats" "cpufreq_governor" "cpufreq_${GOVERNOR}")

  for MODULE in "${REQUIRED_MODULES[@]}"; do
    if ! lsmod | grep -qw "${MODULE}"; then
      MODULE_PATH="/usr/lib/modules/${MODULE}.ko"
      if [ -f "${MODULE_PATH}" ]; then
        insmod "${MODULE_PATH}" 2>/dev/null || echo "Failed to load module: ${MODULE}"
      fi
    fi
  done
fi

# Checked every 10s for at most 60s, and set whenever it is not the one
# asked for: acpi-cpufreq is a module in DSM and can register after this
# service starts -- late on a slow boot, as the first one after a
# migration -- and DSM can change the governor after us. Done once two
# checks in a row find it set.
ok=0
for t in 0 10 20 30 40 50 60; do
  [ "${t}" -gt 0 ] && sleep 10
  if all_cpus_set; then
    ok=$((ok + 1))
    [ "${ok}" -ge 2 ] && break
  else
    ok=0
    set_governor
  fi
done

if all_cpus_set; then
  echo "CPUFreqScaling: All CPUs set to ${GOVERNOR}, exiting."
else
  echo "CPUFreqScaling: Failed to set all CPUs within 60s, exiting."
  pkill -f "scaling.sh" || true
  exit 1
fi