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

WORK_PATHS="/mnt/p1 /mnt/p2 /mnt/p3"
LOADER_DISK="/dev/synoboot"
LOADER_PARTS="/dev/synoboot1 /dev/synoboot2 /dev/synoboot3"

cleanup() {
  for i in 1 2 3; do
    umount "/mnt/p${i}" 2>/dev/null || true
    rm -rf "/mnt/p${i}" 2>/dev/null || true
  done
  reset_arcsu
  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
}

mountLoaderDisk() {
  for part in $LOADER_DISK $LOADER_PARTS; do
    [ ! -b "$part" ] && echo "Loader disk not found: $part" && cleanup && exit 1
  done

  if ! lsmod | grep -qw vfat; then
    modprobe -q vfat
  fi
  echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null

  for i in 1 2 3; do
    umount "/dev/synoboot${i}" 2>/dev/null || true
    rm -rf "/mnt/p${i}" 2>/dev/null || true
    mkdir -p "/mnt/p${i}"
    mount "/dev/synoboot${i}" "/mnt/p${i}" || { echo "Can't mount /dev/synoboot${i}."; cleanup; exit 1; }
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

  echo "Loader disk mount success!"
  "/usr/arc/.mountloader"
}

unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
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
    echo "Loader disk unmount successful!"
    cleanup
  else
    echo "Loader disk isn't currently mounted."
  fi
}

case "$1" in
  mountLoaderDisk)
    mountLoaderDisk
    ;;
  unmountLoaderDisk)
    unmountLoaderDisk
    ;;
  *)
    echo "Usage: $0 {mountLoaderDisk|unmountLoaderDisk}"
    exit 1
    ;;
esac