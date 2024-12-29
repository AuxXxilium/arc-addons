#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon arccontrol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/sbin/arccontrol.sh /tmpRoot/usr/sbin/arccontrol.sh
  cp -pf /addons/arc-control.spk /tmpRoot/usr/arc/addons/arc-control.spk
  cp -pf /addons/python311.spk /tmpRoot/usr/arc/addons/python311.spk
  [ -f "/tmpRoot/usr/bin/arccontrol.sh" ] && rm -f "/tmpRoot/usr/bin/arccontrol.sh" || true

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arccontrol.service"
  {
    echo "[Unit]"
    echo "Description=addon arccontrol"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=simple"
    echo "Restart=on-failure"
    echo "RestartSec=10"
    echo "ExecStart=/usr/sbin/arccontrol.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arccontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arccontrol.service
  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
      echo "copy esynoscheduler.db"
      mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
      cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
    echo "insert reinstall arc-control task to esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'ReinstallArcControl';
INSERT INTO task VALUES('ReinstallArcControl', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/sbin/arccontrol.sh', 'script', '{}', '', '', '{}', '{}');
EOF
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arccontrol - ${1}"
  # To-Do
fi