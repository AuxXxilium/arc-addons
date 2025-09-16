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
ARC_PATH="/tmp/initrd"

cleanup() {
  for i in 1 2 3; do
    umount "/mnt/p${i}" 2>/dev/null || true
    rm -rf "/mnt/p${i}" 2>/dev/null || true
  done
  reset_arcsu
  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
}

mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    for part in $LOADER_DISK $LOADER_PARTS; do
      [ ! -b "$part" ] && echo "Loader disk not found: $part" && cleanup && exit 1
    done

    # Mount partitions
    modprobe -q vfat
    modprobe -q ext2
    modprobe -q ext4
    echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null

    # Check partitions and ignore errors
    [ -f "/sbin/fsck.vfat" ] && fsck.vfat -aw "/dev/synoboot1" >/dev/null 2>&1 || true
    [ -f "/sbin/fsck.ext2" ] && fsck.ext2 -p "/dev/synoboot2" >/dev/null 2>&1 || true
    [ -f "/sbin/fsck.ext4" ] && fsck.ext4 -p "/dev/synoboot3" >/dev/null 2>&1 || true

    for i in 1 2 3; do
      umount "/dev/synoboot${i}" 2>/dev/null || true
      rm -rf "/mnt/p${i}" 2>/dev/null || true
      mkdir -p "/mnt/p${i}"
      mount "/dev/synoboot${i}" "/mnt/p${i}" || { echo "Can't mount /dev/synoboot${i}."; cleanup; exit 1; }
    done

    # Additional functionality: Handle ARC initrd
    INITRD_TOOLPATH="/usr/mountloader"
    ARC_RAMDISK_FILE="/mnt/p3/initrd-arc"
    if [ -d "${INITRD_TOOLPATH}" ] && [ -f "${ARC_RAMDISK_FILE}" ]; then
      rm -rf "${ARC_PATH}"
      mkdir -p "${ARC_PATH}"

      PATH=${INITRD_TOOLPATH}/bin:$PATH
      LD_LIBRARY_PATH=${INITRD_TOOLPATH}/lib:$LD_LIBRARY_PATH
      INITRD_FORMAT=$(file -b --mime-type "${ARC_RAMDISK_FILE}")
      case "${INITRD_FORMAT}" in
      *'x-cpio'*) sh -c "cd ${ARC_PATH} && cpio -idm <${ARC_RAMDISK_FILE} >/dev/null 2>&1" || true ;;
      *'x-xz'*) sh -c "cd ${ARC_PATH} && xz -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *'x-lz4'*) sh -c "cd ${ARC_PATH} && lz4 -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *'x-lzma'*) sh -c "cd ${ARC_PATH} && lzma -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *'x-bzip2'*) sh -c "cd ${ARC_PATH} && bzip2 -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *'gzip'*) sh -c "cd ${ARC_PATH} && gzip -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *'zstd'*) sh -c "cd ${ARC_PATH} && zstd -dc ${ARC_RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
      *) ;;
      esac
      if [ ! -f "${ARC_PATH}/opt/arc/arc.sh" ]; then
        echo "Arc Ramdisk not found!"
        rm -rf "${ARC_PATH}"
        cleanup
        exit 1
      fi
    fi

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

    # Clean up ARC initrd path if it exists
    if [ -d "${ARC_PATH}" ]; then
      rm -rf "${ARC_PATH}" >/dev/null 2>&1 || true
    fi

    # Call the cleanup function to unmount and remove mount points
    cleanup

    sync
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