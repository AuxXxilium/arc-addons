#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

function mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    while true; do
      if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
        echo "Loader disk not found!"
        break
      fi

      echo 1 >/proc/sys/kernel/syno_install_flag

      # Make folders to mount partitions
      for i in {1..3}; do
        rm -rf "/mnt/p${i}"
        mkdir -p "/mnt/p${i}"
        mount -o rw "/dev/synoboot${i}" "/mnt/p${i}" || {
          echo "Can't mount /dev/synoboot${i}."
          break 2
        }
      done

      mkdir -p /usr/arc
      {
        echo "export LOADER_DISK=\"/dev/synoboot\""
        echo "export LOADER_DISK_PART1=\"/dev/synoboot1\""
        echo "export LOADER_DISK_PART2=\"/dev/synoboot2\""
        echo "export LOADER_DISK_PART3=\"/dev/synoboot3\""
      } >"/usr/arc/.mountloader"

      break
    done
  fi
  if [ ! -f "/usr/arc/.mountloader" ]; then
    echo "Loader disk mount failed!"
    return 1
  else
    echo "Loader disk mount success!"
    . "/usr/arc/.mountloader"
    return 0
  fi
}

function unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    rm -f "/usr/arc/.mountloader"

    export LOADER_DISK=
    export LOADER_DISK_PART1=
    export LOADER_DISK_PART2=
    export LOADER_DISK_PART3=

    for i in {1..3}; do
      umount "/mnt/p${i}"
      rm -rf "/mnt/p${i}"
    done

    echo 0 >/proc/sys/kernel/syno_install_flag
  fi
  echo "Loader disk umount success!"
  return 0
}

$@