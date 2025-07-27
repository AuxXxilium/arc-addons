#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "-r" ]; then
  FILE="/sbin/dmidecode"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
else
  FILE="/sbin/dmidecode"
  if [ -x "${FILE}" ]; then
    MEMORY_TOTAL_FILE=$(/sbin/dmidecode -t 17 | grep "Size.*B" | awk '{if ($3=="kB") {s+=$22} else if ($3=="MB") {s+=$2*1024} else if ($3=="GB") {s+=$2*1024*1024} else if ($3=="TB") {s+=$2*1024*1024*1024}} END {print s}')
    MEMORY_TOTAL_PROC=$(awk '"MemTotal:"==$1{print $2}' /proc/meminfo)
    if [ "${MEMORY_TOTAL_FILE:-0}" -lt "${MEMORY_TOTAL_PROC:-0}" ]; then
      mv -vf "${FILE}" "${FILE}.bak"
    fi
  fi
fi

exit 0