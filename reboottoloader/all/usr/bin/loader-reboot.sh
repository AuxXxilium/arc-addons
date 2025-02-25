#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Sanity checks
if [ ! ${USER} = "root" ]; then
  exec sudo $0 $@
fi

MODES="config recovery junior automated update uefi"

function use() {
  echo "Use: ${0} [${MODES// /|}]"
  exit 1
}

if [ -z "${1}" ] || ! echo "${MODES}" | grep -qw "${1}"; then use; fi

echo "Rebooting to ${1} mode"

echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null
mkdir -p /mnt/p1
mount | grep -q /dev/synoboot1 || mount /dev/synoboot1 /mnt/p1 2>/dev/null

GRUBPATH="$(dirname $(find /mnt/p1 -name grub.cfg | head -1))"
if [ -z "${GRUBPATH}" ]; then
  echo "Error: GRUB path not found"
  umount /mnt/p1 2>/dev/null
  exit 1
fi

ENVFILE="${GRUBPATH}/grubenv"

if grub-editenv --help >/dev/null 2>&1; then
  [ ! -f "${ENVFILE}" ] && grub-editenv ${ENVFILE} create
  grub-editenv ${ENVFILE} set next_entry="${1}"
else
  echo "# GRUB Environment Block" >${ENVFILE}
  echo "# WARNING: Do not edit this file by tools other than grub-editenv!!!" >>${ENVFILE}
  echo "next_entry=${1}" >>${ENVFILE}
  printf '%*s' 930 | tr ' ' '#' >>${ENVFILE}
fi
sync
umount /mnt/p1 2>/dev/null

[ -x /usr/syno/sbin/synopoweroff ] && /usr/syno/sbin/synopoweroff -r || reboot