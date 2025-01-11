#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/bin/scaling.sh" "/tmpRoot/usr/bin/scaling.sh"
  [ -f /usr/sbin/scaling.sh ] && rm -f "/usr/sbin/scaling.sh"
  [ -f /tmpRoot/usr/sbin/scaling.sh ] && rm -f "/tmpRoot/usr/sbin/scaling.sh"

  GOVERNOR=$(grep -oP '(?<=governor=)\w+' /proc/cmdline 2>/dev/null)
  if [ "${GOVERNOR}" = "schedutil" ] || [ "${GOVERNOR}" = "ondemand" ] || [ "${GOVERNOR}" = "conservative" ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
    {
      echo "[Unit]"
      echo "Description=Enable CPU Freq scaling"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "User=root"
      echo "Type=simple"
      echo "Restart=on-failure"
      echo "RestartSec=10"
      echo "ExecStart=/usr/bin/scaling.sh ${GOVERNOR}"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"
    mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
    if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
      echo "copy esynoscheduler.db"
      mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
      cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
    echo "insert scaling... task to esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'CPUFreqscaling';
INSERT INTO task VALUES('CPUFreqscaling', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/bin/scaling.sh ${GOVERNOR}', 'script', '{}', '', '', '{}', '{}');
EOF
  fi

elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"

  rm -f /tmpRoot/usr/bin/scaling.sh
fi