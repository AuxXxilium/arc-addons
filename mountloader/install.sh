#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon mountloader - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/yq /tmpRoot/usr/bin/yq
  cp -pf /usr/bin/arc-loaderdisk.sh /tmpRoot/usr/bin/arc-loaderdisk.sh
  
  rm -f /tmpRoot/usr/arc/.mountloader

  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "copy esynoscheduler.db"
    mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
    cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
  fi
  echo "insert mountloader task to esynoscheduler.db"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'MountLoaderDisk';
INSERT INTO task VALUES('MountLoaderDisk', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/bin/arc-loaderdisk.sh mountLoaderDisk', 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'UnMountLoaderDisk';
INSERT INTO task VALUES('UnMountLoaderDisk', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/arc-loaderdisk.sh unmountLoaderDisk', 'script', '{}', '', '', '{}', '{}');
EOF
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon mountloader - ${1}"

  rm -f "/tmpRoot/usr/bin/arc-loaderdisk.sh"

  if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "delete mountloader task from esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'MountLoaderDisk';
DELETE FROM task WHERE task_name LIKE 'UnMountLoaderDisk';
EOF
  fi
fi
