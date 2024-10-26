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
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf "/usr/sbin/scaling.sh" "/tmpRoot/usr/sbin/scaling.sh"
  [ ! -f "/tmpRoot/usr/bin/echo" ] && cp -vf /usr/bin/echo /tmpRoot/usr/bin/echo || true
  cp -f "/usr/lib/modules/acpi_cpufreq.ko" "/tmpRoot/usr/lib/modules/acpi_cpufreq.ko"
  [ "${2}" != "schedutil" ] && cp -vf "/usr/lib/modules/cpufreq_${2}.ko" "/tmpRoot/usr/lib/modules/cpufreq_${2}.ko"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
  cat <<EOF >${DEST}
[Unit]
Description=Enable CPU Freq scaling
Wants=smpkg-custom-install.service
After=smpkg-custom-install.service

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=10
ExecStart=/usr/sbin/scaling.sh ${2}

[Install]
WantedBy=multi-user.target
EOF
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service

  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    echo "copy esynoscheduler.db"
    mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
    cp -vf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
  fi
  echo "insert scaling... task to esynoscheduler.db"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'CPUFreqscaling';
INSERT INTO task VALUES('CPUFreqscaling', '', 'bootup', '', 0, 0, 0, 0, '', 0, '/usr/sbin/scaling.sh ${2}', 'script', '{}', '', '', '{}', '{}');
EOF

elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"

  rm -f /tmpRoot/usr/sbin/scaling.sh
fi