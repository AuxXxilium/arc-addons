#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

args=()

HBA=false
for argv in "$@"; do
  if [ -e "${argv}" ] && readlink -f "/sys/block/$(basename "${argv}")/device" 2>/dev/null | grep -q "expander"; then
    HBA=true
  fi
done

argp=""
for argv in "$@"; do
  if [ "${argp}" = "-d" ] && [ "${argv}" = "ata" ] && [ "${HBA}" = "true" ]; then
    args+=("sat")
  else
    args+=("${argv}")
  fi
  argp="${argv}"
done

/usr/bin/smartctl.bak "${args[@]}"
