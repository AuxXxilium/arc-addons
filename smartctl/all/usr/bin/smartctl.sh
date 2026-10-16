#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

#  -d TYPE, --device=TYPE
#         Specify device type to one of: ata, scsi, nvme[,NSID], sat[,auto][,N][+TYPE], usbcypress[,X], usbjmicron[,p][,x][,N], usbsunplus, marvell, areca,N/E, 3ware,N, hpt,L/M/N, megaraid,N, aacraid,H,L,ID, cciss,N, auto, test

#  smartctl -d ata -A /dev/sdh

args=()

# The probe below is a command to the disk, and only "-d ata" uses what it
# finds: without one, smartctl is called as it was asked, and the disk is
# left alone. With one, the probe keeps the caller's -n, so a disk in
# standby is not spun up by the probe before the call that was meant to
# spare it.
NEED=false
NOCHECK=()
argp=""
for argv in "$@"; do
  [ "${argp}" = "-d" ] && [ "${argv}" = "ata" ] && NEED=true
  case "${argp}" in -n | --nocheck) NOCHECK=(-n "${argv}") ;; esac
  case "${argv}" in --nocheck=*) NOCHECK=("${argv}") ;; esac
  argp="${argv}"
done
[ "${NEED}" = "true" ] || exec /usr/bin/smartctl.bak "$@"

TYPE=ata
for argv in "$@"; do
  if [ -e "${argv}" ]; then
    info=$(/usr/bin/smartctl.bak "${NOCHECK[@]}" -i "${argv}" 2>/dev/null)
    case "${info}" in
      *NVMe*) TYPE="nvme" ;;
      *"SATA Version"*|*"ATA Version"*) TYPE="sat" ;;
      *"Transport protocol: SAS"*) TYPE="scsi" ;;
      *"Unknown USB bridge"*) TYPE="usbcypress" ;;
      *) ;;
    esac
  fi
done

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