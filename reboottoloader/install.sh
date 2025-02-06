#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_reboottoloader() {
  echo "Installing addon reboottoloader - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/loader-reboot.sh /tmpRoot/usr/bin
  cp -pf /usr/bin/grub-editenv /tmpRoot/usr/bin

  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "copy esynoscheduler.db"
    mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
    cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
  fi
  echo "insert reboottoloader task to esynoscheduler.db"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'RebootToLoader';
INSERT INTO task VALUES('RebootToLoader', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/loader-reboot.sh "config"', 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'RebootToUpdate';
INSERT INTO task VALUES('RebootToUpdate', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/loader-reboot.sh "update"', 'script', '{}', '', '', '{}', '{}');
EOF
}

uninstall_reboottoloader() {
  echo "Uninstalling addon reboottoloader - ${1}"

  rm -f /tmpRoot/usr/bin/loader-reboot.sh
  rm -f /tmpRoot/usr/bin/grub-editenv

  if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "delete reboottoloader task from esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'RebootToLoader';
DELETE FROM task WHERE task_name LIKE 'RebootToUpdate';
EOF
  fi
}

case "${1}" in
  late)
    install_reboottoloader "${1}"
    ;;
  uninstall)
    uninstall_reboottoloader "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac