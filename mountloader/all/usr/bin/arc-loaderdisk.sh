#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

[ -f "/bin/arcsu" ] && ARC_SUDO="/bin/arcsu" || ARC_SUDO=""

mountLoaderDisk() {
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

    for i in {1..3}; do
      ${ARC_SUDO} mount | grep -q "/dev/synoboot${i}" && ${ARC_SUDO} umount "/dev/synoboot${i}" 2>/dev/null || true

      ${ARC_SUDO} rm -rf "/mnt/p${i}" 2>/dev/null || true
      ${ARC_SUDO} mkdir -p "/mnt/p${i}"
      if ! ${ARC_SUDO} mount "/dev/synoboot${i}" "/mnt/p${i}"; then
        echo "Can't mount /dev/synoboot${i}."

        for j in {1..3}; do
          ${ARC_SUDO} umount "/mnt/p${i}" 2>/dev/null || true
          ${ARC_SUDO} rm -rf "/mnt/p${i}" 2>/dev/null || true
        done
        break 2
      fi
    done

    mkdir -p "/usr/arc"
    ${ARC_SUDO} touch "/usr/arc/.mountloader"
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
  if [ -f "/usr/arc/.mountloader" ]; then
    echo "Loader disk mount success!"
    ${ARC_SUDO} "/usr/arc/.mountloader"
    return 0
  else
    echo "Loader disk mount failed!"
    return 1
  fi
}

unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    {
      echo "export LOADER_DISK=\"\""
      echo "export LOADER_DISK_PART1=\"\""
      echo "export LOADER_DISK_PART2=\"\""
      echo "export LOADER_DISK_PART3=\"\""
    } | ${ARC_SUDO} tee "/usr/arc/.mountloader" >/dev/null
    ${ARC_SUDO} chmod a+x "/usr/arc/.mountloader"
    ${ARC_SUDO} "/usr/arc/.mountloader"
    ${ARC_SUDO} rm -f "/usr/arc/.mountloader"

    sync

    for i in {1..3}; do
      if ${ARC_SUDO} mount | grep -q "/mnt/p${i}"; then
        ${ARC_SUDO} umount "/mnt/p${i}" 2>/dev/null || true
        ${ARC_SUDO} rm -rf "/mnt/p${i}" 2>/dev/null || true
      fi
    done

    echo 0 | ${ARC_SUDO} tee /proc/sys/kernel/syno_install_flag >/dev/null

    echo "Loader disk unmount successful!"
  else
    echo "Loader disk isn't currently mounted."
  fi
  return 0
}

[ -z "${1}" ] && {
  echo " Usage: $0 [mountLoaderDisk|unmountLoaderDisk]"
  exit 1
}

[ -x "/sbin/arcsu" ] && ARC_SUDO="/sbin/arcsu" || ARC_SUDO=""
${ARC_SUDO} ls /root >/dev/null 2>&1 || {
  echo "No root permission!"
  exit 1
}

"$@"