#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
CPUCORE=$(cat /proc/cpuinfo 2>/dev/null | grep processor | wc -l)
while true; do
  CPUCORE=$((CPUCORE - 1))
  if [ "${PLATFORM}" == "eypc7002" ]; then
    if grep -qw "schedutil" /sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors; then
      echo "schedutil" >/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors
    else
      echo "performance" >/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors
    fi
  else
    if grep -qw "ondemand" /sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors; then
      echo "ondemand" >/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors
    else
      echo "performance" >/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_available_governors
    fi
  fi
  if [ ${CPUCORE} -eq 0 ]; then
    break
  fi
done