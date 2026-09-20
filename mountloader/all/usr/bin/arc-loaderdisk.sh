#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Remove set -e to handle errors explicitly
set -u

# Already root (the arc-control package runs as root) - nothing to escalate.
# Otherwise re-exec through arcsu, by absolute path: a CGI inherits nginx's
# minimal PATH, which need not contain /usr/bin.
if [ "$(id -u)" -ne 0 ]; then
  if [ ! -x /usr/bin/arcsu ]; then
    echo "Error: This script must be run as root or with 'arcsu'."
    exit 1
  fi
  exec env ARCSU_ACTIVE=1 /usr/bin/arcsu "$0" "$@"
fi

reset_arcsu() {
  unset ARCSU_ACTIVE
}

LOADER_DISK="/dev/synoboot"
LOADER_PARTS="/dev/synoboot1 /dev/synoboot2 /dev/synoboot3"
RAMDISK_PATH="/mnt/initrd"
INITRD_TOOLPATH="/usr/mountloader"

# The loader ramdisk on p3, resolved rather than assumed.
#
# This was hardcoded to /mnt/p3/initrd-arc, which is arc's ARC_RAMDISK_FILE
# constant - a name the loader defines and never writes. grub boots
# /initrd-${system_version}, normally initrd-apex, with initrd-user as an
# optional overlay. So the -f test below missed on every current release, and
# because that is a soft branch that only warns, "mountLoaderDisk -all" returned
# success having extracted nothing at all.
#
# Order: what grubenv actually names, then the usual apex, then any other
# initrd-* on p3 - skipping initrd-dsm, which is the built DSM image, and
# initrd-user, which is the user's own overlay. Neither is the loader.
find_ramdisk_file() {
  local version candidate
  version="$(grep -o 'system_version=[A-Za-z0-9._-]*' /mnt/p1/boot/grub/grubenv 2>/dev/null | head -1 | cut -d= -f2)"
  if [ -n "${version}" ] && [ -s "/mnt/p3/initrd-${version}" ]; then
    echo "/mnt/p3/initrd-${version}"; return 0
  fi
  if [ -s "/mnt/p3/initrd-apex" ]; then
    echo "/mnt/p3/initrd-apex"; return 0
  fi
  for candidate in /mnt/p3/initrd-*; do
    [ -s "${candidate}" ] || continue
    case "$(basename "${candidate}")" in
      initrd-dsm|initrd-user) continue ;;
    esac
    echo "${candidate}"; return 0
  done
  return 1
}
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

  # Unmount, then remove the mount point only if it is genuinely empty.
  #
  # This used to be "umount || umount -l || true" followed by an unconditional
  # "rm -rf /mnt/pN", and that pairing destroys data. A lazy unmount detaches
  # the NAME while the filesystem stays attached for anything still holding a
  # reference - another namespace, a bind mount, an open file - so the rm then
  # deletes through a partition that is still live. It has emptied p1, and left
  # p2 and p3 half-deleted, on a running system.
  #
  # So: no lazy fallback, and no rm that is not conditional on the directory
  # actually being an empty, unmounted one. A mount point that cannot be
  # released is left in place and logged; the disk stays mounted, which is
  # recoverable, rather than being deleted through, which is not.
  for i in 1 2 3; do
    if mount | grep -q " /mnt/p${i} "; then
      if umount "/mnt/p${i}" 2>/dev/null; then
        log "Unmounted /mnt/p${i}"
      else
        # One retry after a short pause: a process that just finished with the
        # mount usually lets go within a second.
        sleep 1
        if umount "/mnt/p${i}" 2>/dev/null; then
          log "Unmounted /mnt/p${i} (second attempt)"
        else
          log "WARNING: /mnt/p${i} is busy and was left mounted - NOT removing it"
          continue
        fi
      fi
    fi

    # Only now, with nothing mounted there, is removing it safe. rmdir rather
    # than rm -rf: it refuses a non-empty directory, so if anything unexpected
    # is present it is kept rather than destroyed.
    if [ -d "/mnt/p${i}" ] && ! mount | grep -q " /mnt/p${i} "; then
      rmdir "/mnt/p${i}" 2>/dev/null || log "Left /mnt/p${i} in place (not empty)"
    fi
  done

  # Same reasoning for the extracted ramdisk. It is a plain directory tree
  # rather than a mount, so rm -rf is right - but only once nothing is mounted
  # inside it, or that rm walks into whatever is.
  if [ -d "${RAMDISK_PATH}" ]; then
    if mount | grep -q " ${RAMDISK_PATH}"; then
      log "WARNING: something is mounted under ${RAMDISK_PATH} - NOT removing it"
    else
      rm -rf "${RAMDISK_PATH}" 2>/dev/null || true
      log "Cleaned up ramdisk"
    fi
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
      if ! mount | grep -q " /mnt/p${i} "; then
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
    if mount | grep -q " /mnt/p${i} "; then
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
    # Resolved here rather than at the top of the file: p3 has only just been
    # mounted, so this is the first point at which the image can be found.
    RAMDISK_FILE="$(find_ramdisk_file || echo "")"
    [ -n "${RAMDISK_FILE}" ] && log "Ramdisk image: ${RAMDISK_FILE}" \
      || log "WARN: no loader ramdisk found on /mnt/p3"
    if [ -n "${RAMDISK_FILE}" ] && [ -f "${RAMDISK_FILE}" ] && [ -d "${INITRD_TOOLPATH}" ]; then
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
        if mount | grep -q " /mnt/p${i} "; then
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