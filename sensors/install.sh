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

    if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
      echo "copy esynoscheduler.db"
      mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
      cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if echo "SELECT * FROM task;" | /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" | grep -E "Fancontrol" -A11 | grep -Eq "^FANMODES=(.*)$"; then
      echo "Fancontrol task already exists"
    else
      echo "insert sensors task to esynoscheduler.db"
      /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
INSERT INTO task VALUES('Fancontrol', '', 'bootup', '', 0, 0, 0, 0, '', 0, '
# You only need to modify the following 12 values. You need to change the FanMode once. You do not need to run the task.
#
#                       fullfan             coolfan               quietfan
#                          |                      |                        |
FANMODES=("20 50 50 100" "20 60 20 60" "20 70 10 50")
#                    ^  ^   ^   ^
#                    1  2    3    4
# 1: MINTEMP  2: MAXTEMP  3: MINPWM  4: MAXPWM
# MINPWM and MAXPWM are in percent (0-100)
', 'script', '{}', '', '', '{}', '{}');
EOF
    fi

    mkdir -p "/tmpRoot/usr/lib/systemd/system"
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
      echo "StartLimitBurst=5"
      echo "StartLimitInterval=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"/tmpRoot/usr/lib/systemd/system/sensors.service"

    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/sensors.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service
  else
    echo "fancontrol disabled, skipping installation"
    rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
    rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"
    rm -f "/tmpRoot/usr/bin/arc-sensors.sh"
    rm -f "/tmpRoot/usr/bin/arc-pwm.sh"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if [ -f "${ESYNOSCHEDULER_DB}" ]; then
      echo "delete fancontrol task from esynoscheduler.db"
      /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
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
  rm -f "/tmpRoot/usr/bin/arc-pwm.sh"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete fancontrol task from esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol';
EOF
  fi
fi