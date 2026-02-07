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
FILENAME="${PRE}_$(date +%Y%m%d%H%M%S).dss"
mkdir -p "${DSMBPATH}"
/usr/syno/bin/synoconfbkp export --filepath="${DSMBPATH}/${FILENAME}"
echo "Backup to ${DSMBPATH}/${FILENAME}"

for I in $(LC_ALL=C printf '%s\n' ${SCBKPATH}/${PRE}*.dss | sort -r | awk "NR>${NUM}"); do
  rm -f "${I}"
done

LOADER_DISK_PART1="$(/sbin/blkid -L ARC1 2>/dev/null)"
 if [ ! -b "${LOADER_DISK_PART1}" ] && [ -b "/dev/synoboot1" ]; then
  LOADER_DISK_PART1="/dev/synoboot1"
fi
if [ ! -b "${LOADER_DISK_PART1}" ]; then
  echo "Boot disk not found"
  exit 1
fi

modprobe -q vfat
echo 1 >/proc/sys/kernel/syno_install_flag 2>/dev/null
[ -f "/sbin/fsck.vfat" ] && fsck.vfat -aw "${LOADER_DISK_PART1}" >/dev/null 2>&1 || true
WORK_PATH="/mnt/p1"
mkdir -p "${WORK_PATH}"
mount | grep -q "${LOADER_DISK_PART1}" && umount "${LOADER_DISK_PART1}" 2>/dev/null || true
mount "${LOADER_DISK_PART1}" "${WORK_PATH}" || {
  echo "Can't mount ${LOADER_DISK_PART1}."
  rm -rf "${WORK_PATH}"
  echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null
  exit 1
}

rm -rf "${WORK_PATH}/dsmbackup"
cp -rf "${DSMBPATH}" "${WORK_PATH}"

sync

umount "${LOADER_DISK_PART1}" 2>/dev/null
rm -rf "${WORK_PATH}"

echo 0 >/proc/sys/kernel/syno_install_flag 2>/dev/null

echo "Backup to /mnt/p1/dsmbackup/"

exit 0