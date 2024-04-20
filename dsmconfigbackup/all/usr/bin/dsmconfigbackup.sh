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
PRE="${2:-dsm}"

BACKUPPATH="/usr/arc/dsmbackup"
FILENAME="${PRE}_$(date +%Y%m%d%H%M%S).dss"
mkdir -p "${BACKUPPATH}"
/usr/syno/bin/synoconfbkp export --filepath="${BACKUPPATH}/${FILENAME}"
echo "Backup to ${BACKUPPATH}/${FILENAME}"

for I in $(ls ${BACKUPPATH}/${PRE}*.dss | sort -r | awk "NR>${NUM}"); do
  rm -f "${I}"
done

PART1_PATH="$(cat /proc/mounts | grep '/dev/synoboot1' | cut -d' ' -f2)"
if [ -z "${PART1_PATH}" ]; then
  echo 1 >/proc/sys/kernel/syno_install_flag
  mkdir -p /mnt/p1
  mount /dev/synoboot1 /mnt/p1
  [ $? -ne 0 ] && exit 1
  rm -rf /mnt/p1/dsmbackup
  cp -rf "${BACKUPPATH}" /mnt/p1/
  sync
  umount /mnt/p1
  echo 0 >/proc/sys/kernel/syno_install_flag
else
  rm -rf "${PART1_PATH}/dsmbackup"
  cp -rf "${BACKUPPATH}" "${PART1_PATH}/"
  sync
fi
echo "Backup to /mnt/p1/dsmbackup"

exit 0