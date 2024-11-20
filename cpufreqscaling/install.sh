#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/sbin/scaling.sh" "/tmpRoot/usr/sbin/scaling.sh"
  [ ! -f "/tmpRoot/usr/bin/echo" ] && cp -pf /usr/bin/echo /tmpRoot/usr/bin/echo || true
  if [ "${2}" = "schedutil" ] || [ "${2}" = "ondemand" ] || [ "${2}" = "conservative" ]; then
    cp -pf "/usr/lib/modules/acpi_cpufreq.ko" "/tmpRoot/usr/lib/modules/acpi_cpufreq.ko"
  fi
  [ "${2}" != "schedutil" ] && cp -pf "/usr/lib/modules/cpufreq_${2}.ko" "/tmpRoot/usr/lib/modules/cpufreq_${2}.ko"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
  {
    echo "[Unit]"
    echo "Description=Enable CPU Freq scaling"
    echo "After=syno-volume.target syno-space.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=simple"
    echo "Restart=on-failure"
    echo "RestartSec=10"
    echo "ExecStart=/usr/sbin/scaling.sh ${2}"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
  if [ "${2}" = "schedutil" ] || [ "${2}" = "ondemand" ] || [ "${2}" = "conservative" ]; then
    if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
      echo "copy esynoscheduler.db"
      mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
      cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
    echo "insert scaling... task to esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
      /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'CPUFreqscaling';
INSERT INTO task VALUES('CPUFreqscaling', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/sbin/scaling.sh ${2}', 'script', '{}', '', '', '{}', '{}');
EOF
  fi

elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"

  rm -f /tmpRoot/usr/sbin/scaling.sh
fi