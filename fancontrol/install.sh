#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon fancontrol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/bin/arc-fancontrol.sh /tmpRoot/usr/bin/arc-fancontrol.sh

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -wq "task"; then
    echo "copy esynoscheduler.db"
    mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
    cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
  fi
  if echo "SELECT * FROM task;" | /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" | grep -E "Fancontrol" -A10 | grep -Eq "^FANMODES=(.*)$"; then
    echo "Fancontrol task already exists"
  else
      echo "insert sensors task to esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
INSERT INTO task VALUES('Fancontrol', '', 'bootup', '', 0, 0, 0, 0, '', 0, '
# You only need to modify the following 12 values. You need to change the FanMode once. You do not need to run the task.
#
#                       fullfan             coolfan               quietfan
#                          |                      |                        |
FANMODES=("20 50 100 50" "20 60 80 20" "20 80 50 20")
#                    ^  ^   ^   ^
#                    1  2    3    4
# 1: MINTEMP  2: MAXTEMP  3: MINSTART  4: MINSTOP
# MINSTART and MINSTOP are in percent (0–100)
', 'script', '{}', '', '', '{}', '{}');
EOF
  fi

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/fancontrol.service"
  {
    echo "[Unit]"
    echo "Description=Arc fancontrol daemon"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=forking"
    echo "ExecStart=/usr/bin/arc-fancontrol.sh"
    echo "ExecReload=/usr/bin/pkill -f /usr/bin/arc-fancontrol.sh"
    echo "Restart=always"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/fancontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/fancontrol.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon fancontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/fancontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/fancontrol.service"

  rm -f /tmpRoot/etc/fancontrol
  rm -f /tmpRoot/usr/bin/arc-fancontrol.sh

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete fancontrol task from esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
EOF
  fi
fi
exit 0