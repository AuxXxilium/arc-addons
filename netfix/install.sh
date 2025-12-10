#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "modules" ]; then
  ETHX="$(find /sys/class/net/ -mindepth 1 -maxdepth 1 -name 'eth*' -exec basename {} \; | sort)"
  for N in ${ETHX}; do
    RMAC="$(cat /proc/cmdline | grep -o "R${N}=[^ ]*" | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
    
    if ! echo "${RMAC}" | grep -Eq '^[0-9a-f]{12}$'; then
      echo "Error: Invalid RMAC value for ${N}: ${RMAC}"
      continue
    fi
  
    MAC="$(cat /sys/class/net/${N}/address 2>/dev/null | sed 's/://g' | tr '[:upper:]' '[:lower:]')"
    
    # Validate and set MAC address
    if [ -n "${RMAC}" ] && [ "${MAC}" != "${RMAC}" ]; then
      ifconfig ${N} down 2>/dev/null
      ifconfig ${N} hw ether "$(echo ${RMAC} | sed 's/../&:/g; s/:$//')" 2>/dev/null
      ifconfig ${N} up 2>/dev/null
      echo "Set MAC address for ${N}: $(echo ${RMAC} | sed 's/../&:/g; s/:$//')"
    fi
  done
fi