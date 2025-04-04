#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Sanity checks
if [ ! "${USER}" = "root" ]; then
  exec sudo "$0" "$@"
fi

MODES="config recovery junior automated update uefi"

use() {
  echo "Use: ${0} [ $(echo "${MODES}" | sed 's/ /|/g') ]"
  exit 1
}

if [ -z "${1}" ] || ! echo "${MODES}" | grep -wq "${1}"; then use; fi

echo "Rebooting to ${1} mode"

LOADER_DISK_PART1="$(/sbin/blkid -L ARC1 2>/dev/null)"
if [ ! -b "${LOADER_DISK_PART1}" ] && [ -b "/dev/synoboot1" ]; then
  LOADER_DISK_PART1="/dev/synoboot1"
fi
if [ ! -b "${LOADER_DISK_PART1}" ]; then
  echo "Boot disk not found"
  exit 1
fi

modprobe -q vfat
echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null
WORK_PATH="/mnt/p1"
mkdir -p "${WORK_PATH}"
mount | grep -q "${LOADER_DISK_PART1}" && umount "${LOADER_DISK_PART1}" 2>/dev/null || true
mount "${LOADER_DISK_PART1}" "${WORK_PATH}" || {
  echo "Can't mount ${LOADER_DISK_PART1}."
  rm -rf "${WORK_PATH}"
  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
  exit 1
}

GRUBPATH="$(dirname "$(find "${WORK_PATH}" -name grub.cfg | head -1)")"
if [ -z "${GRUBPATH}" ]; then
  echo "Error: GRUB path not found"
  umount "${LOADER_DISK_PART1}" 2>/dev/null
  rm -rf "${WORK_PATH}"
  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
  exit 1
fi

ENVFILE="${GRUBPATH}/grubenv"

if grub-editenv --help >/dev/null 2>&1; then
  [ ! -f "${ENVFILE}" ] && grub-editenv "${ENVFILE}" create
  grub-editenv "${ENVFILE}" set next_entry="${1}"
else
  if [ ! -f "${ENVFILE}" ]; then
    {
      echo "# GRUB Environment Block"
      echo "# WARNING: Do not edit this file by tools other than grub-editenv!!!"
      echo "next_entry=${1}"
    } >"${ENVFILE}"
  else
    sed -i "/^#\{1,\}$/d" "${ENVFILE}"
    if grep -q "^next_entry=" "${ENVFILE}"; then
      sed -i "s/^next_entry=.*/next_entry=${1}/" "${ENVFILE}"
    else
      printf "next_entry=${1}\n" >>"${ENVFILE}"
    fi
  fi
  #for i in $(seq 1 $((1024 - $(cat "${ENVFILE}" 2>/dev/null | wc -c)))); do printf "#"; done >> "${ENVFILE}"
  printf '%*s' $((1024 - $(cat "${ENVFILE}" 2>/dev/null | wc -c))) "" | tr ' ' '#' >>"${ENVFILE}"
fi

sync

umount "${LOADER_DISK_PART1}" 2>/dev/null
rm -rf "${WORK_PATH}"
echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null

[ -x /usr/syno/sbin/synopoweroff ] && /usr/syno/sbin/synopoweroff -r || /sbin/reboot