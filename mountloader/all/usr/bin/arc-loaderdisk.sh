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
RAMDISK_PATH="/mnt/initrd"
RAMDISK_FILE="/mnt/p3/initrd-arc"
INITRD_TOOLPATH="/usr/mountloader"

cleanup() {
  for i in 1 2 3; do
    umount "/mnt/p${i}" 2>/dev/null || true
    rm -rf "/mnt/p${i}" 2>/dev/null || true
  done
  rm -rf "${RAMDISK_PATH}" 2>/dev/null || true
  echo 0 | tee /proc/sys/kernel/syno_install_flag >/dev/null
  reset_arcsu
}

mountLoaderDisk() {
  if [ ! -f "/usr/arc/.mountloader" ]; then
    while true; do
      for part in $LOADER_DISK $LOADER_PARTS; do
        [ ! -b "${part}" ] && cleanup && break 2
      done

      # Mount partitions
      modprobe -q vfat || true
      modprobe -q ext2 || true
      modprobe -q ext4 || true
      echo 1 | tee /proc/sys/kernel/syno_install_flag >/dev/null

      for i in 1 2 3; do
        if ! mount | grep -q "/mnt/p${i}"; then
          rm -rf "/mnt/p${i}" 2>/dev/null || true
          mkdir -p "/mnt/p${i}"
          mount "/dev/synoboot${i}" "/mnt/p${i}" || {
            cleanup
            break 2
          }
        fi
      done

      # Mount ramdisk if the file exists
      if echo "$@" | grep -wq "\-all"; then
        if [ -f "${RAMDISK_FILE}" ] && [ -d "${INITRD_TOOLPATH}" ]; then
          rm -rf "${RAMDISK_PATH}"
          mkdir -p "${RAMDISK_PATH}"

          PATH=${INITRD_TOOLPATH}/bin:$PATH
          LD_LIBRARY_PATH=${INITRD_TOOLPATH}/lib:$LD_LIBRARY_PATH
          export LD_LIBRARY_PATH
          
          # Set the MAGIC environment variable to point to the correct magic.mgc file
          export MAGIC=${INITRD_TOOLPATH}/share/misc/magic.mgc
          
          # Detect the ramdisk format
          INITRD_FORMAT=$(file -b --mime-type "${RAMDISK_FILE}")
          case "${INITRD_FORMAT}" in
            *'x-cpio'*) sh -c "cd ${RAMDISK_PATH} && cpio -idm <${RAMDISK_FILE} >/dev/null 2>&1" || true ;;
            *'x-xz'*) sh -c "cd ${RAMDISK_PATH} && xz -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *'x-lz4'*) sh -c "cd ${RAMDISK_PATH} && lz4 -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *'x-lzma'*) sh -c "cd ${RAMDISK_PATH} && lzma -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *'x-bzip2'*) sh -c "cd ${RAMDISK_PATH} && bzip2 -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *'gzip'*) sh -c "cd ${RAMDISK_PATH} && gzip -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *'zstd'*) sh -c "cd ${RAMDISK_PATH} && zstd -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || true ;;
            *) cleanup && break 2;;
          esac
          if [ ! -f "${RAMDISK_PATH}/opt/arc/arc.sh" ]; then
            rm -rf "${RAMDISK_PATH}"
            cleanup
            break
          fi
        else
          cleanup
          break
        fi
      fi

      mkdir -p "/usr/arc"
      {
        echo "export LOADER_DISK=\"/dev/synoboot\""
        echo "export LOADER_DISK_PART1=\"/dev/synoboot1\""
        echo "export LOADER_DISK_PART2=\"/dev/synoboot2\""
        echo "export LOADER_DISK_PART3=\"/dev/synoboot3\""
        if [ -f "${RAMDISK_PATH}/opt/arc/arc.sh" ]; then
          echo "export ARC_PATH=\"${RAMDISK_PATH}/opt/arc\""
          echo "export ARC_MODE=\"config\""
        fi
      } > "/usr/arc/.mountloader"

      if [ ! -f "/usr/arc/.mountloader" ]; then
        cleanup
        exit 1
      fi

      chmod a+x "/usr/arc/.mountloader"
      sync
      break
    done
    "/usr/arc/.mountloader"
  fi
}

unmountLoaderDisk() {
  if [ -f "/usr/arc/.mountloader" ]; then
    {
      echo "export LOADER_DISK=\"\""
      echo "export LOADER_DISK_PART1=\"\""
      echo "export LOADER_DISK_PART2=\"\""
      echo "export LOADER_DISK_PART3=\"\""
      if [ -f "${RAMDISK_PATH}/opt/arc/arc.sh" ]; then
        rm -rf "${RAMDISK_PATH}" >/dev/null 2>&1 || true
        echo "export ARC_PATH=\"\""
        echo "export ARC_MODE=\"\""
      fi
    } | tee "/usr/arc/.mountloader"
    chmod a+x "/usr/arc/.mountloader"
    "/usr/arc/.mountloader"
    rm -f "/usr/arc/.mountloader"

    sync

    cleanup
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