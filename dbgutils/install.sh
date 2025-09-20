#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

getlog() {
  if [ -z "${1}" ]; then
    echo "Usage: ${0} {early|jrExit|rcExit|late|dsm}"
    exit 1
  fi

  LOADER_DISK_PART1="$(/sbin/blkid -L AR1 2>/dev/null)"
   if [ ! -b "${LOADER_DISK_PART1}" ] && [ -b "/dev/synoboot1" ]; then
    LOADER_DISK_PART1="/dev/synoboot1"
  fi
  if [ ! -b "${LOADER_DISK_PART1}" ]; then
    echo "Boot disk not found"
    exit 1
  fi

  modprobe -q vfat
  echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null
  [ -f "/sbin/fsck.vfat" ] && fsck.vfat -aw "${LOADER_DISK_PART1}" >/dev/null 2>&1 || true

  WORK_PATH="/mnt/p1"
  mkdir -p "${WORK_PATH}"
  mount | grep -q "${LOADER_DISK_PART1}" && umount "${LOADER_DISK_PART1}" 2>/dev/null || true
  mount "${LOADER_DISK_PART1}" "${WORK_PATH}" || {
    echo "Can't mount ${LOADER_DISK_PART1}."
    exit 1
  }

  DEST_PATH="${WORK_PATH}/logs/${1}"
  rm -rf "${DEST_PATH}"
  mkdir -p "${DEST_PATH}"

  dmesg >"${DEST_PATH}/dmesg.log"
  lsmod >"${DEST_PATH}/lsmod.log"
  lspci -nnk >"${DEST_PATH}/lspci.log" || true
  ip addr >"${DEST_PATH}/ip-addr.log" || true
  ip link >"${DEST_PATH}/ip-link.log" || true
  ip route >"${DEST_PATH}/ip-route.log" || true

  ls -l /sys/class/net/*/device/driver >"${DEST_PATH}/net-driver.log" || true

  ls -l /sys/class/block >"${DEST_PATH}/disk-block.log" || true
  ls -l /sys/class/scsi_host >"${DEST_PATH}/disk-scsi_host.log" || true
  cat /sys/block/*/device/syno_block_info >"${DEST_PATH}/disk-syno_block_info.log" || true

  [ -f "/addons/addons.sh" ] && cp -pf "/addons/addons.sh" "${DEST_PATH}/addons.sh" || true
  [ -f "/addons/model.dts" ] && cp -pf "/addons/model.dts" "${DEST_PATH}/model.dts" || true

  [ -f "/var/log/messages" ] && cp -pf "/var/log/messages" "${DEST_PATH}/messages" || true
  [ -f "/var/log/linuxrc.syno.log" ] && cp -pf "/var/log/linuxrc.syno.log" "${DEST_PATH}/linuxrc.syno.log" || true
  [ -f "/tmp/installer_sh.log" ] && cp -pf "/tmp/installer_sh.log" "${DEST_PATH}/installer_sh.log" || true

  sync
  umount "${LOADER_DISK_PART1}" 2>/dev/null
  rm -rf "${WORK_PATH}"

  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
}

if [ "${1}" = "early" ]; then
  echo "Installing addon dbgutils - ${1}"
  getlog "${1}"
elif [ "${1}" = "jrExit" ]; then
  echo "Installing addon dbgutils - ${1}"
  getlog "${1}"
elif [ "${1}" = "rcExit" ]; then
  echo "Installing addon dbgutils - ${1}"
  getlog "${1}"
elif [ "${1}" = "late" ]; then
  echo "Installing addon dbgutils - ${1}"
  getlog "${1}"
fi