#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "modules" ] || [ "${1}" = "late" ]; then
  ETHX="$(find /sys/class/net/ -mindepth 1 -maxdepth 1 -name 'eth*' -exec basename {} \; | sort)"
  for N in ${ETHX}; do
    RMAC="$(cat /proc/cmdline | grep "R${N}=" | cut -d'=' -f2)"
    ip link set dev ${N} address ${RMAC}
    echo "Set MAC address for ${N}: ${RMAC}"
  done
fi