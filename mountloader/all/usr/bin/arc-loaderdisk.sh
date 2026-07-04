#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Remove set -e to handle errors explicitly
set -u

if [ -z "${ARCSU_ACTIVE:-}" ]; then
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
LOCK_FILE="/var/run/arc-loaderdisk.lock"
MAX_RETRY=3
RETRY_DELAY=2

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> /var/log/arc-loaderdisk.log
}

# Acquire lock to prevent concurrent execution
acquire_lock() {
  local retry=0
  while [ $retry -lt $MAX_RETRY ]; do
    if mkdir "$LOCK_FILE" 2>/dev/null; then
      trap release_lock EXIT INT TERM
      log "Lock acquired"
      return 0
    fi
    log "Lock exists, waiting... (attempt $((retry+1))/$MAX_RETRY)"
    sleep $RETRY_DELAY
    retry=$((retry+1))
  done
  log "Failed to acquire lock after $MAX_RETRY attempts"
  return 1
}

# Release lock
release_lock() {
  if [ -d "$LOCK_FILE" ]; then
    rmdir "$LOCK_FILE" 2>/dev/null || true
    log "Lock released"
  fi
  trap - EXIT INT TERM
}

cleanup() {
  log "Running cleanup"
  
  # Sync before unmounting
  sync
  
  # Force unmount with retries
  for i in 1 2 3; do
    if mount | grep -q "/mnt/p${i}"; then
      umount "/mnt/p${i}" 2>/dev/null || umount -l "/mnt/p${i}" 2>/dev/null || true
      log "Unmounted /mnt/p${i}"
    fi
    rm -rf "/mnt/p${i}" 2>/dev/null || true
  done
  
  # Clean up ramdisk
  if [ -d "${RAMDISK_PATH}" ]; then
    rm -rf "${RAMDISK_PATH}" 2>/dev/null || true
    log "Cleaned up ramdisk"
  fi
  
  echo 0 | tee /proc/sys/kernel/syno_install_flag >/dev/null 2>&1 || true
  reset_arcsu
}

function mountLoaderDisk() {
  log "mountLoaderDisk called with args: $*"
  
  # Acquire lock
  if ! acquire_lock; then
    log "ERROR: Could not acquire lock"
    return 1
  fi
  
  # Check if already mounted
  if [ -f "/usr/arc/.mountloader" ]; then
    log "Loader already mounted, checking validity..."
    local all_mounted=true
    for i in 1 2 3; do
      if ! mount | grep -q "/mnt/p${i}"; then
        log "WARNING: Partition p${i} not mounted despite .mountloader exists"
        all_mounted=false
        break
      fi
    done
    
    if $all_mounted; then
      log "All partitions already mounted"
      release_lock
      return 0
    else
      log "Stale mount detected, cleaning up..."
      rm -f "/usr/arc/.mountloader"
    fi
  fi
  
  # Validate loader disk exists
  if [ ! -b "$LOADER_DISK" ]; then
    log "ERROR: Loader disk $LOADER_DISK not found"
    release_lock
    return 1
  fi
  
  # Validate all partitions exist
  for part in $LOADER_PARTS; do
    if [ ! -b "$part" ]; then
      log "ERROR: Partition $part not found"
      cleanup
      release_lock
      return 1
    fi
  done
  
  # Load required modules
  log "Loading kernel modules"
  modprobe -q vfat 2>/dev/null || true
  modprobe -q ext2 2>/dev/null || true
  modprobe -q ext4 2>/dev/null || true
  echo 1 | tee /proc/sys/kernel/syno_install_flag >/dev/null 2>&1 || true
  
  # Mount partitions with retry logic
  for i in 1 2 3; do
    if mount | grep -q "/mnt/p${i}"; then
      log "Partition p${i} already mounted, skipping"
      continue
    fi
    
    log "Mounting /dev/synoboot${i} to /mnt/p${i}"
    rm -rf "/mnt/p${i}" 2>/dev/null || true
    mkdir -p "/mnt/p${i}"
    
    local retry=0
    local fstype
    fstype="$(blkid -o value -s TYPE "/dev/synoboot${i}" 2>/dev/null || echo "")"
    while [ $retry -lt $MAX_RETRY ]; do
      if mount ${fstype:+-t "${fstype}"} "/dev/synoboot${i}" "/mnt/p${i}" 2>/dev/null; then
        log "Successfully mounted /dev/synoboot${i} (type: ${fstype:-auto})"
        break
      fi
      log "Mount failed, retrying... (attempt $((retry+1))/$MAX_RETRY)"
      sleep 1
      retry=$((retry+1))
    done
    
    if [ $retry -eq $MAX_RETRY ]; then
      log "ERROR: Failed to mount /dev/synoboot${i} after $MAX_RETRY attempts"
      cleanup
      release_lock
      return 1
    fi
  done
  
  # Mount ramdisk if the file exists and -all flag is present
  if echo "$@" | grep -wq "\-all"; then
    log "Mounting ramdisk (-all flag detected)"
    if [ -f "${RAMDISK_FILE}" ] && [ -d "${INITRD_TOOLPATH}" ]; then
      rm -rf "${RAMDISK_PATH}"
      mkdir -p "${RAMDISK_PATH}"

      PATH=${INITRD_TOOLPATH}/bin:$PATH
      LD_LIBRARY_PATH=${INITRD_TOOLPATH}/lib:${LD_LIBRARY_PATH:-}
      export LD_LIBRARY_PATH
      export MAGIC=${INITRD_TOOLPATH}/share/misc/magic.mgc
      
      # Detect the ramdisk format
      INITRD_FORMAT=$(file -b --mime-type "${RAMDISK_FILE}" 2>/dev/null || echo "unknown")
      log "Ramdisk format detected: $INITRD_FORMAT"
      
      case "${INITRD_FORMAT}" in
        *'x-cpio'*) sh -c "cd ${RAMDISK_PATH} && cpio -idm <${RAMDISK_FILE} >/dev/null 2>&1" || log "WARN: cpio extraction failed" ;;
        *'x-xz'*) sh -c "cd ${RAMDISK_PATH} && xz -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: xz extraction failed" ;;
        *'x-lz4'*) sh -c "cd ${RAMDISK_PATH} && lz4 -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: lz4 extraction failed" ;;
        *'x-lzma'*) sh -c "cd ${RAMDISK_PATH} && lzma -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: lzma extraction failed" ;;
        *'x-bzip2'*) sh -c "cd ${RAMDISK_PATH} && bzip2 -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: bzip2 extraction failed" ;;
        *'gzip'*) sh -c "cd ${RAMDISK_PATH} && gzip -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: gzip extraction failed" ;;
        *'zstd'*) sh -c "cd ${RAMDISK_PATH} && zstd -dc ${RAMDISK_FILE} | cpio -idm >/dev/null 2>&1" || log "WARN: zstd extraction failed" ;;
        *) 
          log "ERROR: Unknown ramdisk format: $INITRD_FORMAT"
          cleanup
          release_lock
          return 1
          ;;
      esac
      
      if [ ! -f "${RAMDISK_PATH}/opt/arc/arc.sh" ]; then
        log "ERROR: Ramdisk extraction failed - arc.sh not found"
        rm -rf "${RAMDISK_PATH}"
        cleanup
        release_lock
        return 1
      fi
      log "Ramdisk mounted successfully"
    else
      log "WARN: Ramdisk file or tools not found, skipping ramdisk mount"
    fi
  fi

  # Create mount state file
  log "Creating mount state file"
  mkdir -p "/usr/arc"
  {
    echo 'export LOADER_DISK="/dev/synoboot"'
    echo 'export LOADER_DISK_PART1="/dev/synoboot1"'
    echo 'export LOADER_DISK_PART2="/dev/synoboot2"'
    echo 'export LOADER_DISK_PART3="/dev/synoboot3"'
    if [ -f "${RAMDISK_PATH}/opt/arc/arc.sh" ]; then
      echo 'export ARC_PATH="${RAMDISK_PATH}/opt/arc"'
      echo 'export ARC_MODE="config"'
    fi
  } > "/usr/arc/.mountloader"

  if [ ! -f "/usr/arc/.mountloader" ]; then
    log "ERROR: Failed to create mount state file"
    cleanup
    release_lock
    return 1
  fi

  chmod a+x "/usr/arc/.mountloader"
  sync
  
  # Source the mount state
  . "/usr/arc/.mountloader"
  
  log "Loader disk mounted successfully"
  release_lock
  return 0
}

function unmountLoaderDisk() {
  log "unmountLoaderDisk called"
  
  # Acquire lock
  if ! acquire_lock; then
    log "ERROR: Could not acquire lock"
    return 1
  fi
  
  if [ -f "/usr/arc/.mountloader" ]; then
    log "Unmounting loader disk"
    
    # Clear environment variables
    {
      echo 'export LOADER_DISK=""'
      echo 'export LOADER_DISK_PART1=""'
      echo 'export LOADER_DISK_PART2=""'
      echo 'export LOADER_DISK_PART3=""'
      if [ -d "${RAMDISK_PATH}" ]; then
        log "Cleaning up ramdisk"
        rm -rf "${RAMDISK_PATH}" 2>/dev/null || true
        echo 'export ARC_PATH=""'
        echo 'export ARC_MODE=""'
      fi
    } > "/usr/arc/.mountloader"
    
    chmod a+x "/usr/arc/.mountloader"
    . "/usr/arc/.mountloader" 2>/dev/null || true
    rm -f "/usr/arc/.mountloader"
    
    # Sync before cleanup
    log "Syncing filesystems"
    sync
    sleep 1
    
    # Run cleanup
    cleanup
    
    log "Loader disk unmounted successfully"
  else
    log "Loader not mounted (no .mountloader file)"
  fi
  
  release_lock
  return 0
}

case "${1:-}" in
  mountLoaderDisk)
    mountLoaderDisk "$@"
    ;;
  unmountLoaderDisk)
    unmountLoaderDisk "$@"
    ;;
  status)
    # Show mount status
    if [ -f "/usr/arc/.mountloader" ]; then
      echo "Loader disk: MOUNTED"
      for i in 1 2 3; do
        if mount | grep -q "/mnt/p${i}"; then
          echo "  /mnt/p${i}: mounted"
        else
          echo "  /mnt/p${i}: NOT mounted (ERROR)"
        fi
      done
      if [ -d "${RAMDISK_PATH}" ]; then
        echo "  Ramdisk: mounted"
      fi
    else
      echo "Loader disk: NOT MOUNTED"
    fi
    ;;
  *)
    echo "Usage: $0 {mountLoaderDisk|unmountLoaderDisk|status}"
    exit 1
    ;;
esac