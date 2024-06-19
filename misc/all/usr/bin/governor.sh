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
  if [ "${PLATFORM}" = "epyc7002" ]; then
    echo "schedutil" >"/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_governor"
    echo "set schedutil governor for ${PLATFORM} cpu: ${CPUCORE}"
  else
    echo "ondemand" >"/sys/devices/system/cpu/cpu${CPUCORE}/cpufreq/scaling_governor"
    echo "set ondemand governor for ${PLATFORM} cpu: ${CPUCORE}"
  fi
  if [ ${CPUCORE} -eq 0 ]; then
    break
  fi
done