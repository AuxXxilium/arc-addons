#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "-r" ]; then
  FILE="/sbin/dmidecode"
  # The backup is DSM's dmidecode itself, moved aside rather than patched. One
  # in place again is a DSM update's own, and the moved one is not put over it.
  if [ -e "${FILE}" ]; then
    rm -f "${FILE}.bak"
  elif [ -f "${FILE}.bak" ]; then
    mv -f "${FILE}.bak" "${FILE}"
  fi
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