#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

[ -f "/sbin/arcsu" ] && ARC_SUDO="/sbin/arcsu" || ARC_SUDO=""

mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    while true; do
      if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
        echo "Loader disk not found!"
        break
      fi

      # Mount partitions
      modprobe -q vfat
      modprobe -q ext2
      modprobe -q ext4
      echo 1 | ${ARC_SUDO} tee /proc/sys/kernel/syno_install_flag >/dev/null

      # Check partitions and ignore earcors
      [ -f "/sbin/fsck.vfat" ] && ${ARC_SUDO} fsck.vfat -aw "/dev/synoboot1" >/dev/null 2>&1 || true
      [ -f "/sbin/fsck.ext2" ] && ${ARC_SUDO} fsck.ext2 -p "/dev/synoboot2" >/dev/null 2>&1 || true
      [ -f "/sbin/fsck.ext4" ] && ${ARC_SUDO} fsck.ext4 -p "/dev/synoboot3" >/dev/null 2>&1 || true

      # Make folders to mount partitions
      for i in {1..3}; do
        ${ARC_SUDO} rm -rf "/mnt/p${i}"
        ${ARC_SUDO} mkdir -p "/mnt/p${i}"
        ${ARC_SUDO} mount | grep -q "/dev/synoboot${i}" && ${ARC_SUDO} umount "/dev/synoboot${i}" || true
        ${ARC_SUDO} mount "/dev/synoboot${i}" "/mnt/p${i}" || {
          echo "Can't mount /dev/synoboot${i}."
          for j in {1..3}; do
            ${ARC_SUDO} umount "/mnt/p${j}" 2>/dev/null || true
            ${ARC_SUDO} rm -rf "/mnt/p${j}" 2>/dev/null || true
          done
          break 2
        }
      done

      mkdir -p "/usr/arc"
      {
        echo "export LOADER_DISK=\"/dev/synoboot\""
        echo "export LOADER_DISK_PART1=\"/dev/synoboot1\""
        echo "export LOADER_DISK_PART2=\"/dev/synoboot2\""
        echo "export LOADER_DISK_PART3=\"/dev/synoboot3\""
      } | ${ARC_SUDO} tee "/usr/arc/.mountloader" >/dev/null
      ${ARC_SUDO} chmod a+x "/usr/arc/.mountloader"

      sync

      break
    done
  fi
  if [ ! -f "/usr/arc/.mountloader" ]; then
    echo "Loader disk mount failed!"
    return 1
  else
    echo "Loader disk mount success!"
    ${ARC_SUDO} "/usr/arc/.mountloader"
    return 0
  fi
}

unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    {
      echo "export LOADER_DISK=\"\""
      echo "export LOADER_DISK_PART1=\"\""
      echo "export LOADER_DISK_PART2=\"\""
      echo "export LOADER_DISK_PART3=\"\""
      if [ -f "${RR_PATH}/opt/arc/menu.sh" ]; then
        ${ARC_SUDO} rm -rf "${RR_PATH}" >/dev/null 2>&1 || true
        echo "export WORK_PATH=\"\""
      fi
    } | ${ARC_SUDO} tee "/usr/arc/.mountloader" >/dev/null
    ${ARC_SUDO} chmod a+x "/usr/arc/.mountloader"
    ${ARC_SUDO} "/usr/arc/.mountloader"
    ${ARC_SUDO} rm -f "/usr/arc/.mountloader"

    sync

    if echo "$@" | grep -wq "\-all"; then
      ${ARC_SUDO} rm -rf "${RR_PATH}"
    fi
    for j in {1..3}; do
      ${ARC_SUDO} umount "/mnt/p${j}" 2>/dev/null || true
      ${ARC_SUDO} rm -rf "/mnt/p${j}" 2>/dev/null || true
    done

    echo 0 | ${ARC_SUDO} tee /proc/sys/kernel/syno_install_flag >/dev/null
  fi
  echo "Loader disk umount success!"
  return 0
}

"$@"