#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> & Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon monitor - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/monitor-7.1.tgz -C /tmpRoot/
  cp -vpf /usr/bin/arc-monitor.sh /tmpRoot/usr/bin/arc-monitor.sh

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -qw "task"; then
    echo "copy esynoscheduler.db"
    mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
    cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
  fi
  if echo "SELECT * FROM task;" | /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" | grep -Eq "PowerOnMonitor|PowerOffMonitor"; then
    echo "PowerOnMonitor/PowerOffMonitor task already exists and it is enabled"
  else
    echo "insert PowerOnMonitor/PowerOffMonitor task to esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'PowerOnMonitor';
INSERT INTO task VALUES('PowerOnMonitor', '', 'bootup', '', 0, 0, 0, 0, '', 0, "/usr/bin/arc-monitor.sh on", 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'PowerOffMonitor';
INSERT INTO task VALUES('PowerOffMonitor', '', 'bootup', '', 1, 0, 0, 0, '', 0, "/usr/bin/arc-monitor.sh off", 'script', '{}', '', '', '{}', '{}');
EOF
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon monitor - ${1}"

  rm -rf /tmpRoot/usr/bin/monitor
  rm -rf /tmpRoot/usr/lib/libdrm*
  rm -rf /tmpRoot/usr/lib/libpciaccess*

  rm -f "/tmpRoot/usr/bin/arc-monitor.sh"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete setrootpw task from esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'PowerOnMonitor';
DELETE FROM task WHERE task_name LIKE 'PowerOffMonitor';
EOF
  fi
fi
