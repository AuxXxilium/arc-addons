#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Check if /usr/bin/arcsu exists
ARCSU=""
if [ -x "/usr/bin/arcsu" ]; then
  ARCSU="/usr/bin/arcsu"
fi

args=()

HBA=false
for argv in "$@"; do
  if [ -e "${argv}" ] && ! readlink -f "/sys/block/$(basename "${argv}")/device" 2>/dev/null | grep -q "/ata"; then
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

${ARCSU} /usr/bin/smartctl.bak "${args[@]}"
