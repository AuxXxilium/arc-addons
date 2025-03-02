#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon rebootto... - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/loader-reboot.sh /tmpRoot/usr/bin
  cp -pf /usr/bin/grub-editenv /tmpRoot/usr/bin

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ ! -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "copy esynoscheduler.db"
    mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
    cp -pf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
  fi
  echo "insert rebootto... task to esynoscheduler.db"
  /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'RebootToLoader';
INSERT INTO task VALUES('RebootToLoader', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/loader-reboot.sh "config"', 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'RebootToUpdate';
INSERT INTO task VALUES('RebootToUpdate', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/loader-reboot.sh "update"', 'script', '{}', '', '', '{}', '{}');
EOF
}

uninstall_addon() {
  echo "Uninstalling addon rebootto... - ${1}"

  rm -f /tmpRoot/usr/bin/loader-reboot.sh
  rm -f /tmpRoot/usr/bin/grub-editenv

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete rebootto... task from esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'RebootToLoader';
DELETE FROM task WHERE task_name LIKE 'RebootToUpdate';
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