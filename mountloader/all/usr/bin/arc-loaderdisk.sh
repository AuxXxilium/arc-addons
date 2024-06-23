#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

function extractInitrd() {
  [ -z "${1}" -o -z "${2}" ] && return 1

  if [ -f "${1}" ]; then
    rm -rf "${2}"
    mkdir -p "${2}"
    (
      cd "${2}"
      xz -dc <"${1}" | cpio -idm
    ) >/dev/null 2>&1 || true
  fi
  return 0
}

function mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    while true; do
      if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
        echo "Loader disk not found!"
        break
      fi

      echo 1 >/proc/sys/kernel/syno_install_flag

      # Make folders to mount partitions
      mkdir -p /mnt/p1
      mkdir -p /mnt/p2
      mkdir -p /mnt/p3

      mount /dev/synoboot1 /mnt/p1 2>/dev/null || (
        echo "Can't mount /dev/synoboot1"
        break
      )
      mount /dev/synoboot2 /mnt/p2 2>/dev/null || (
        echo "Can't mount /dev/synoboot2"
        break
      )
      mount /dev/synoboot3 /mnt/p3 2>/dev/null || (
        echo "Can't mount /dev/synoboot3"
        break
      )

      ARC_RAMDISK_FILE="/mnt/p3/initrd-arc"
      ARC_PATH="/tmp/initrd"
      extractInitrd "${ARC_RAMDISK_FILE}" "${ARC_PATH}"
      if [ ! -f "${ARC_PATH}/opt/arc/arc.sh" ]; then
        echo "ARC initrd work path not found!"
        break
      fi

      mkdir -p /usr/arc
      echo "export LOADER_DISK=\"/dev/synoboot\"" >"/usr/arc/.mountloader"
      echo "export LOADER_DISK_PART1=\"/dev/synoboot1\"" >>"/usr/arc/.mountloader"
      echo "export LOADER_DISK_PART2=\"/dev/synoboot2\"" >>"/usr/arc/.mountloader"
      echo "export LOADER_DISK_PART3=\"/dev/synoboot3\"" >>"/usr/arc/.mountloader"
      echo "export WORK_PATH=\"${ARC_PATH}/opt/arc\"" >>"/usr/arc/.mountloader"
      break
    done
  fi
  if [ ! -f "/usr/arc/.mountloader" ]; then
    echo "Loader disk mount failed!"
    return 1
  else
    echo "Loader disk mount success!"
    . /usr/arc/.mountloader
    return 0
  fi
}

function unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    rm -f "/usr/arc/.mountloader"

    sync

    export LOADER_DISK=
    export LOADER_DISK_PART1=
    export LOADER_DISK_PART2=
    export LOADER_DISK_PART3=

    ARC_PATH="/tmp/initrd"
    rm -rf "${ARC_PATH}"

    umount /mnt/p1 2>/dev/null
    umount /mnt/p2 2>/dev/null
    umount /mnt/p3 2>/dev/null
    rm -rf /mnt/p1 /mnt/p2 /mnt/p3

    echo 0 >/proc/sys/kernel/syno_install_flag
  fi
  echo "Loader disk umount success!"
  return 0
}

$@
