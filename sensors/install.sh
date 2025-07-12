#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon sensors - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/sensors-7.1.tgz -C /tmpRoot/usr/

  if [ -f "/addons/fancontrol.sh" ]; then
    cp -vpf /usr/bin/arc-sensors.sh /tmpRoot/usr/bin/arc-sensors.sh
    cp -vpf /usr/bin/arc-pwm.sh /tmpRoot/usr/bin/arc-pwm.sh

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
FANMODES=("20 50 100 50" "20 70 80 20" "20 70 50 10")
#                    ^  ^   ^   ^
#                    1  2    3    4
# 1: MINTEMP  2: MAXTEMP  3: MINSTART  4: MINSTOP
# MINSTART and MINSTOP are in percent (0-100)
', 'script', '{}', '', '', '{}', '{}');
EOF
    fi

    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/sensors.service"
    {
      echo "[Unit]"
      echo "Description=sensors daemon"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Type=forking"
      echo "ExecStart=/usr/bin/arc-sensors.sh"
      echo "ExecReload=/usr/bin/pkill -f /usr/bin/arc-sensors.sh"
      echo "Restart=always"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"

    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/sensors.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service
  else
    echo "fancontrol disabled, skipping installation"
    rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
    rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"
    rm -f "/tmpRoot/etc/fancontrol"
    rm -f "/tmpRoot/usr/bin/arc-sensors.sh"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if [ -f "${ESYNOSCHEDULER_DB}" ]; then
      echo "delete fancontrol task from esynoscheduler.db"
      /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
EOF
    fi
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon sensors - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"

  rm -f "/tmpRoot/etc/fancontrol"
  rm -f "/tmpRoot/usr/bin/arc-sensors.sh"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete fancontrol task from esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
EOF
  fi
fi