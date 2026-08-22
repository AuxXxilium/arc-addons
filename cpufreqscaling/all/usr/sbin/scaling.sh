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
  # a CPU with no cpufreq policy must not count as "set" - if none are present
  # yet this has to fail, otherwise the loop below reports success over an
  # empty set and never writes the governor at all
  found=0
  for cpu in /sys/devices/system/cpu/cpu*; do
    [ -d "${cpu}/cpufreq" ] || continue
    found=$((found + 1))
    [ "$(cat "${cpu}/cpufreq/scaling_governor" 2>/dev/null)" != "${GOVERNOR}" ] && return 1
  done
  [ "${found}" -gt 0 ]
}

wait_for_cpufreq() {
  # acpi-cpufreq may register after multi-user.target, so the policies are not
  # guaranteed to exist when this service starts
  for _ in {1..30}; do
    for cpu in /sys/devices/system/cpu/cpu*; do
      [ -d "${cpu}/cpufreq" ] && return 0
    done
    sleep 2
  done
  return 1
}

load_governor_modules() {
  GOV_MODULES=""
  for DIR in /usr/lib/modules; do
    [ -d "${DIR}" ] || continue
    GOV_MODULES="$(find "${DIR}" -name 'cpufreq_*.ko*' -type f 2>/dev/null \
      | sed 's|.*/||; s|\.ko.*$||' \
      | sort -u)"
    [ -n "${GOV_MODULES}" ] && break
  done

  # Try the known set anyway; modprobe -q simply fails for the ones absent.
  if [ -z "${GOV_MODULES}" ]; then
    GOV_MODULES="cpufreq_ondemand cpufreq_conservative cpufreq_userspace cpufreq_powersave cpufreq_performance cpufreq_interactive"
  fi

  LOADED=""
  for MODULE in acpi_cpufreq cpufreq_governor cpufreq_stats ${GOV_MODULES}; do
    if lsmod | grep -qw "${MODULE}"; then
      LOADED="${LOADED} ${MODULE}"
    elif /usr/sbin/modprobe -q "${MODULE}" 2>/dev/null; then
      LOADED="${LOADED} ${MODULE}"
    fi
  done
  echo "CPUFreqScaling: Governor modules loaded:${LOADED:- none}"
}

echo "CPUFreqScaling: Starting CPU frequency scaling setup"

# Load the modules unconditionally, before any early exit. The governors have to
# exist as loaded modules for anything to select them - including S99governor.sh
# below, which only writes scaling_governor and loads nothing itself.
load_governor_modules

# An explicit choice in Arc Control outranks the boot cmdline, which is only the
# default for a system nobody has configured. Both write the same sysfs files at
# overlapping times during boot, so without this the last writer would win.
ARCCONTROL_OVERRIDE="/usr/local/etc/rc.d/S99governor.sh"
if [ -f "${ARCCONTROL_OVERRIDE}" ]; then
  echo "CPUFreqScaling: Arc Control override present, modules loaded, leaving governor to it"
  exit 0
fi

GOVERNOR="$(grep -o 'governor=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"

if [ -z "${GOVERNOR}" ]; then
  echo "CPUFreqScaling: No governor specified, exiting"
  exit 1
fi

if ! wait_for_cpufreq; then
  echo "CPUFreqScaling: No CPUs with cpufreq support found, exiting"
  exit 1
fi

# applies to every governor - schedutil is not guaranteed to be compiled in
AVAIL_GOV_FILE=""
for cpu in /sys/devices/system/cpu/cpu*; do
  [ -f "${cpu}/cpufreq/scaling_available_governors" ] && AVAIL_GOV_FILE="${cpu}/cpufreq/scaling_available_governors" && break
done
if [ -n "${AVAIL_GOV_FILE}" ] && ! grep -qw "${GOVERNOR}" "${AVAIL_GOV_FILE}" 2>/dev/null; then
  echo "CPUFreqScaling: ${GOVERNOR} governor not available (have: $(cat "${AVAIL_GOV_FILE}" 2>/dev/null)), falling back to ondemand"
  GOVERNOR="ondemand"
fi

# write first, then verify - checking first lets a premature pass skip the write
for i in {1..3}; do
  set_governor
  all_cpus_set && break
  sleep 10
done

if all_cpus_set; then
  echo "CPUFreqScaling: All CPUs set to ${GOVERNOR}, exiting."
else
  echo "CPUFreqScaling: Failed to set all CPUs after 3 tries, exiting."
  exit 1
fi