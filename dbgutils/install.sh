#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

function getlog() {
  [ -z "${1}" ] && echo "Usage: ${0} {early|jrExit|rcExit|late|dsm}" && exit 1

  WORK_PATH="/mnt/p1"
  mkdir -p "${WORK_PATH}"

  if ! mount | grep -q "${WORK_PATH}"; then
    LOADER_DISK_PART1="$(blkid -L ARC1)"
    [ -z "${LOADER_DISK_PART1}" -a -b "/dev/synoboot1" ] && LOADER_DISK_PART1="/dev/synoboot1"
    [ -z "${LOADER_DISK_PART1}" ] && echo "Boot disk not found" && exit 1

    modprobe vfat
    echo 1 >/proc/sys/kernel/syno_install_flag
    mount "${LOADER_DISK_PART1}" "${WORK_PATH}"
  fi

  DEST_PATH="${WORK_PATH}/logs/${1}"
  rm -rf "${DEST_PATH}"
  mkdir -p "${DEST_PATH}"

  dmesg >"${DEST_PATH}/dmesg.log"
  lsmod >"${DEST_PATH}/lsmod.log"
  lspci -Qnnk >"${DEST_PATH}/lspci.log" || true
 
  ls -l /sys/class/net/*/device/driver >"${DEST_PATH}/net-driver.log" || true

  ls -l /sys/class/block >"${DEST_PATH}/disk-block.log" || true
  ls -l /sys/class/scsi_host >"${DEST_PATH}/disk-scsi_host.log" || true
  cat /sys/block/*/device/syno_block_info >"${DEST_PATH}/disk-syno_block_info.log" || true

  [ -f "/addons/addons.sh" ] && cp -f "/addons/addons.sh" "${DEST_PATH}/addons.sh" || true
  [ -f "/addons/model.dts" ] && cp -f "/addons/model.dts" "${DEST_PATH}/model.dts" || true

  [ -f "/var/log/messages" ] && cp -f "/var/log/messages" "${DEST_PATH}/messages" || true
  [ -f "/var/log/linuxrc.syno.log" ] && cp -f "/var/log/linuxrc.syno.log" "${DEST_PATH}/linuxrc.syno.log" || true
  [ -f "/tmp/installer_sh.log" ] && cp -f "/tmp/installer_sh.log" "${DEST_PATH}/installer_sh.log" || true
  
  sync
  umount "${WORK_PATH}"
  rm -rf "${WORK_PATH}"
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
