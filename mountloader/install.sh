#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

export LD_LIBRARY_PATH=/tmpRoot/usr/bin:/tmpRoot/usr/lib

install_addon() {
  echo "Installing addon mountloader - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/bin/yq /tmpRoot/usr/bin/yq

  [ ! -f /tmpRoot/usr/sbin/fatlabel ] && cp -vpf /usr/sbin/fatlabel /tmpRoot/usr/sbin/fatlabel
  [ ! -f /tmpRoot/usr/sbin/dosfslabel ] && ln -vsf fatlabel /tmpRoot/usr/sbin/dosfslabel
  [ ! -f /tmpRoot/usr/sbin/fsck.fat ] && cp -vpf /usr/sbin/fsck.fat /tmpRoot/usr/sbin/fsck.fat
  [ ! -f /tmpRoot/usr/sbin/dosfsck ] && ln -vsf fsck.fat /tmpRoot/usr/sbin/dosfsck
  [ ! -f /tmpRoot/usr/sbin/fsck.msdos ] && ln -vsf fsck.fat /tmpRoot/usr/sbin/fsck.msdos
  [ ! -f /tmpRoot/usr/sbin/fsck.vfat ] && ln -vsf fsck.fat /tmpRoot/usr/sbin/fsck.vfat
  [ ! -f /tmpRoot/usr/sbin/mkfs.fat ] && cp -vpf /usr/sbin/mkfs.fat /tmpRoot/usr/sbin/mkfs.fat
  [ ! -f /tmpRoot/usr/sbin/mkdosfs ] && ln -vsf mkfs.fat /tmpRoot/usr/sbin/mkdosfs
  [ ! -f /tmpRoot/usr/sbin/mkfs.msdos ] && ln -vsf mkfs.fat /tmpRoot/usr/sbin/mkfs.msdos
  [ ! -f /tmpRoot/usr/sbin/mkfs.vfat ] && ln -vsf mkfs.fat /tmpRoot/usr/sbin/mkfs.vfat

  [ ! -f /tmpRoot/usr/sbin/arcsu ] && ln -vsf /usr/bin/sudo /tmpRoot/usr/sbin/arcsu
  chown root:root /tmpRoot/sbin/arcsu
  chmod u+s /tmpRoot/sbin/arcsu

  cp -pf /usr/bin/arc-loaderdisk.sh /tmpRoot/usr/bin/arc-loaderdisk.sh
  
  rm -f /tmpRoot/usr/arc/.mountloader

  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -wq "task"; then
    echo "copy esynoscheduler.db"
    mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
    cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
  fi
  echo "insert mountloader task to esynoscheduler.db"
  /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'MountLoaderDisk';
INSERT INTO task VALUES('MountLoaderDisk', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/bin/arc-loaderdisk.sh mountLoaderDisk', 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'UnMountLoaderDisk';
INSERT INTO task VALUES('UnMountLoaderDisk', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/arc-loaderdisk.sh unmountLoaderDisk', 'script', '{}', '', '', '{}', '{}');
EOF
}

uninstall_addon() {
  echo "Uninstalling addon mountloader - ${1}"

  rm -f "/tmpRoot/usr/bin/arc-loaderdisk.sh"

  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete mountloader task from esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'MountLoaderDisk';
DELETE FROM task WHERE task_name LIKE 'UnMountLoaderDisk';
EOF
  fi
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0