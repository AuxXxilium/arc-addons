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

  # Remove old fancontrol addon remnants
  rm -f "/tmpRoot/usr/sbin/fancontrol" 2>/dev/null || true
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/fancontrol.service" 2>/dev/null || true
  rm -f "/tmpRoot/usr/lib/systemd/system/fancontrol.service" 2>/dev/null || true
  rm -f "/tmpRoot/usr/bin/arc-pwm.sh" 2>/dev/null || true

  if grep -wq "fancontrol" /proc/cmdline 2>/dev/null; then
    cp -pf /usr/bin/arc-sensors.sh /tmpRoot/usr/bin/arc-sensors.sh
    if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
      echo "copy esynoscheduler.db"
      mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
      cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib:/tmpRoot/usr/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if echo "SELECT * FROM task;" | /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" | grep -q "^Fancontrol 2.0|"; then
      echo "Fancontrol 2.0 task already exists, will be updated at boot by arc-sensors.sh"
    else
      echo "insert Fancontrol 2.0 task to esynoscheduler.db"
      /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol 2.0';
INSERT INTO task VALUES('Fancontrol 2.0', '', 'bootup', '', 0, 0, 0, 0, '', 0, '# Populated on first boot by arc-sensors.sh', 'script', '{}', '', '', '{}', '{}');
EOF
    fi

    # libsensors (used by fan2go) requires /etc/sensors3.conf to exist
    touch "/tmpRoot/etc/sensors3.conf"

    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    {
      echo "[Unit]"
      echo "Description=sensors/fancontrol daemon"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Type=simple"
      echo "ExecStart=/usr/bin/arc-sensors.sh"
      echo "Restart=always"
      echo "RestartSec=5"
      echo "StartLimitBurst=5"
      echo "StartLimitInterval=60"
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
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib:/tmpRoot/usr/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if [ -f "${ESYNOSCHEDULER_DB}" ]; then
      echo "delete fancontrol task from esynoscheduler.db"
      /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol 2.0';
EOF
    fi
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon sensors - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"

  rm -rf "/tmpRoot/etc/fan2go"
  rm -f "/tmpRoot/var/lib/fan2go/fan2go.db"
  rm -f "/tmpRoot/usr/bin/arc-sensors.sh"
  rm -f "/tmpRoot/usr/bin/arc-pwm.sh"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete fancontrol task from esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'Fancontrol 2.0';
EOF
  fi
fi