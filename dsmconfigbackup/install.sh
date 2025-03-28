#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon synoconfbkp - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/dsmconfigbackup.sh /tmpRoot/usr/bin/dsmconfigbackup.sh
  
  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "copy esynoscheduler.db"
    mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
    cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
  fi
  echo "insert synoconfbkp task to esynoscheduler.db"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'SynoconfbkpBootup';
INSERT INTO task VALUES('SynoconfbkpBootup', '', 'bootup', '', 1, 0, 0, 0, '', 0, "/usr/bin/dsmconfigbackup.sh ${2:-7} ${3:-bkp}_bootup", 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'SynoconfbkpShutdown';
INSERT INTO task VALUES('SynoconfbkpShutdown', '', 'shutdown', '', 1, 0, 0, 0, '', 0, "/usr/bin/dsmconfigbackup.sh ${2:-7} ${3:-bkp}_shutdown", 'script', '{}', '', '', '{}', '{}');
EOF
}

uninstall_addon() {
  echo "Uninstalling addon synoconfbkp - ${1}"

  rm -f "/tmpRoot/usr/bin/dsmconfigbackup.sh"

  if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "delete synoconfbkp task from esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'SynoconfbkpBootup';
DELETE FROM task WHERE task_name LIKE 'SynoconfbkpShutdown';
EOF
  fi
}

case "${1}" in
  late)
    install_addon "${1}" "${2}" "${3}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0