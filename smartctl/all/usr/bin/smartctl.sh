#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

#  -d TYPE, --device=TYPE
#         Specify device type to one of: ata, scsi, nvme[,NSID], sat[,auto][,N][+TYPE], usbcypress[,X], usbjmicron[,p][,x][,N], usbsunplus, marvell, areca,N/E, 3ware,N, hpt,L/M/N, megaraid,N, aacraid,H,L,ID, cciss,N, auto, test

#  smartctl -d ata -A /dev/sdh

args=()

TYPE=ata
# for argv in "$@"; do
#   if [ -e "${argv}" ]; then
#     info=$(/usr/bin/smartctl.bak -i "${argv}" 2>/dev/null)
#     if echo "${info}" | grep -q "NVMe"; then
#       TYPE="nvme"
#     elif echo "${info}" | grep -q "SATA Version\|ATA Version"; then
#       TYPE="ata"
#     elif echo "${info}" | grep -q "Transport protocol: SAS"; then
#       TYPE="scsi"
#     elif echo "${info}" | grep -q "Unknown USB bridge"; then
#       TYPE="usbcypress"
#     else
#       TYPE="auto"
#     fi
#   fi
# done

argp=""
for argv in "$@"; do
  if [ "${argp}" = "-d" ] && [ "${argv}" = "ata" ]; then
    args+=("${TYPE}")
  else
    args+=("${argv}")
  fi
  argp="${argv}"
done

/usr/bin/smartctl.bak "${args[@]}"