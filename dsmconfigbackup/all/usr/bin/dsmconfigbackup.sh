#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# email
# cat /usr/syno/etc/synosmtp.conf
# gvfs
# ls /var/tmp/user/1026/gvfs/  /usr/syno/etc/synovfs/1026

NUM="${1:-7}"
PRE="${2:-bkp}"

DSMBPATH="/usr/arc/dsmbackup"
BACKUP_DIR="backup"
FILENAME="${PRE}_$(date +%Y%m%d%H%M%S).dss"

# Keep the newest ${NUM} ${PRE}_*.dss in a directory. The timestamped names
# sort chronologically, so a reverse sort puts the newest first.
rotate() {
  local I
  for I in $(LC_ALL=C printf '%s\n' "${1}/${PRE}"_*.dss | sort -r | awk "NR>${NUM}"); do
    [ -f "${I}" ] && rm -f "${I}"
  done
}

# Where a partition is already mounted, if anywhere. Matched by device number,
# not by name: the same partition shows up as /dev/synoboot3 or /dev/sdX3
# depending on who mounted it, and a plain grep for /dev/sda1 also hits sda10.
mounted_at() {
  local WANT DEV MNT REST
  WANT="$(stat -Lc '%t:%T' "${1}" 2>/dev/null)" || return 1
  while read -r DEV MNT REST; do
    [ -b "${DEV}" ] || continue
    [ "$(stat -Lc '%t:%T' "${DEV}" 2>/dev/null)" = "${WANT}" ] || continue
    printf '%b\n' "${MNT}"
    return 0
  done </proc/mounts
  return 1
}

mkdir -p "${DSMBPATH}"
/usr/syno/bin/synoconfbkp export --filepath="${DSMBPATH}/${FILENAME}"
if [ ! -s "${DSMBPATH}/${FILENAME}" ]; then
  echo "synoconfbkp export failed"
  exit 1
fi
echo "Backup to ${DSMBPATH}/${FILENAME}"
rotate "${DSMBPATH}"

# /dev/synoboot3 is the loader DSM actually booted from. Prefer it over the
# ARC3 label: with a second loader disk attached (an old stick, a cloned disk)
# more than one partition carries that label and blkid picks any of them.
LOADER_DISK_PART3=""
if [ -b "/dev/synoboot3" ]; then
  LOADER_DISK_PART3="/dev/synoboot3"
else
  LABELED="$(/sbin/blkid 2>/dev/null | awk -F: '/LABEL="ARC3"/ {print $1}')"
  if [ "$(echo "${LABELED}" | grep -c .)" -gt 1 ]; then
    echo "More than one ARC3 partition found, not guessing which one is the loader:"
    echo "${LABELED}"
    exit 1
  fi
  LOADER_DISK_PART3="${LABELED}"
fi
if [ ! -b "${LOADER_DISK_PART3}" ]; then
  echo "Boot disk not found"
  exit 1
fi

echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null
trap 'echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null' EXIT

# Already mounted (mountloader, a user shell): write through that mount and
# leave it alone. Unmounting it here used to break the other user, and a failed
# unmount followed by rm -rf of the mount point wiped the partition.
WORK_PATH="$(mounted_at "${LOADER_DISK_PART3}")"
OWN_MOUNT=""
if [ -z "${WORK_PATH}" ]; then
  WORK_PATH="$(mktemp -d /tmp/dsmconfigbackup.XXXXXX)" || exit 1
  FSTYPE="$(/sbin/blkid -o value -s TYPE "${LOADER_DISK_PART3}" 2>/dev/null)"
  if ! mount ${FSTYPE:+-t "${FSTYPE}"} "${LOADER_DISK_PART3}" "${WORK_PATH}"; then
    echo "Can't mount ${LOADER_DISK_PART3}."
    rmdir "${WORK_PATH}" 2>/dev/null
    exit 1
  fi
  OWN_MOUNT="${WORK_PATH}"
fi

RC=0
mkdir -p "${WORK_PATH}/${BACKUP_DIR}" &&
  cp -f "${DSMBPATH}/${FILENAME}" "${WORK_PATH}/${BACKUP_DIR}/" || RC=1
rotate "${WORK_PATH}/${BACKUP_DIR}"
sync

if [ -n "${OWN_MOUNT}" ]; then
  # rmdir, never rm -rf: if the unmount did not happen, rmdir fails on the
  # still-mounted directory instead of deleting the loader's files.
  umount "${OWN_MOUNT}" 2>/dev/null && rmdir "${OWN_MOUNT}" 2>/dev/null ||
    echo "Could not unmount ${OWN_MOUNT}, left in place"
fi

if [ ${RC} -ne 0 ]; then
  echo "Copy to ${LOADER_DISK_PART3} failed"
  exit 1
fi
echo "Backup to ${LOADER_DISK_PART3}:/${BACKUP_DIR}/${FILENAME}"

exit 0
