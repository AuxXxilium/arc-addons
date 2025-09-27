#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -e

if [ -z "$ARCSU_ACTIVE" ]; then
  exec env ARCSU_ACTIVE=1 arcsu "$0" "$@"
fi

reset_arcsu() {
  unset ARCSU_ACTIVE
}

LOADER_DISK="/dev/synoboot"
LOADER_PARTS="/dev/synoboot1 /dev/synoboot2 /dev/synoboot3"

cleanup() {
  for i in 1 2 3; do
    umount "/mnt/p${i}" 2>/dev/null || true
    rm -rf "/mnt/p${i}" 2>/dev/null || true
  done
  echo 0 | tee /proc/sys/kernel/syno_install_flag >/dev/null
  reset_arcsu
}

mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    for part in $LOADER_DISK $LOADER_PARTS; do
      [ ! -b "${part}" ] && echo "Loader disk not found: $part" && cleanup && exit 1
    done

    # Mount partitions
    modprobe -q vfat || true
    modprobe -q ext2 || true
    modprobe -q ext4 || true
    echo 1 | tee /proc/sys/kernel/syno_install_flag >/dev/null

    # Check partitions and ignore errors
    [ -f "/sbin/fsck.vfat" ] && fsck.vfat -aw "/dev/synoboot1" >/dev/null 2>&1 || true
    [ -f "/sbin/fsck.ext2" ] && fsck.ext2 -p "/dev/synoboot2" >/dev/null 2>&1 || true
    [ -f "/sbin/fsck.ext4" ] && fsck.ext4 -p "/dev/synoboot3" >/dev/null 2>&1 || true

    for i in 1 2 3; do
      umount "/dev/synoboot${i}" 2>/dev/null || true
      rm -rf "/mnt/p${i}" 2>/dev/null || true
      mkdir -p "/mnt/p${i}"
      mount "/dev/synoboot${i}" "/mnt/p${i}" || {
        echo "Can't mount /dev/synoboot${i}."
        cleanup
        exit 1
      }
    done

    mkdir -p "/usr/arc"
    {
      echo "export LOADER_DISK=\"/dev/synoboot\""
      echo "export LOADER_DISK_PART1=\"/dev/synoboot1\""
      echo "export LOADER_DISK_PART2=\"/dev/synoboot2\""
      echo "export LOADER_DISK_PART3=\"/dev/synoboot3\""
    } > "/usr/arc/.mountloader"
    chmod a+x "/usr/arc/.mountloader"

    sync

    echo "Loader disk mount successful!"
    "/usr/arc/.mountloader"
  else
    echo "Loader disk mount is not possible."
  fi
}

unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    # Clear environment variables related to the loader disk
    {
      echo "export LOADER_DISK=\"\""
      echo "export LOADER_DISK_PART1=\"\""
      echo "export LOADER_DISK_PART2=\"\""
      echo "export LOADER_DISK_PART3=\"\""
    } > "/usr/arc/.mountloader"
    chmod a+x "/usr/arc/.mountloader"
    "/usr/arc/.mountloader"
    rm -f "/usr/arc/.mountloader"

    sync

    cleanup
    echo "Loader disk unmount successful!"
  else
    echo "Loader disk isn't currently mounted."
  fi
}

case "$1" in
  mountLoaderDisk)
    mountLoaderDisk "$@"
    ;;
  unmountLoaderDisk)
    unmountLoaderDisk "$@"
    ;;
  *)
    echo "Usage: $0 {mountLoaderDisk|unmountLoaderDisk}"
    exit 1
    ;;
esac