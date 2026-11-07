#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon powersched - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/" /tmpRoot/usr/bin /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/sbin/powersched /tmpRoot/usr/sbin/powersched
  cp -vpf /usr/bin/powersched.sh /tmpRoot/usr/bin/powersched.sh
  chmod +x /tmpRoot/usr/bin/powersched.sh

  # A service rather than a crontab line: see powersched.sh. The line an
  # earlier version added is taken out - only it, as only it was ours.
  rm -f /tmpRoot/etc/crontab.bak
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null

  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/powersched.service"
[Unit]
Description=Arc power schedule (RTC wake alarm)

[Service]
Type=simple
ExecStart=/usr/bin/powersched.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  ln -vsf /usr/lib/systemd/system/powersched.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/powersched.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon powersched - ${1}"

  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/powersched.service
  rm -f /tmpRoot/usr/lib/systemd/system/powersched.service
  rm -f /tmpRoot/usr/bin/powersched.sh
  rm -f /tmpRoot/usr/sbin/powersched
  rm -f /tmpRoot/etc/crontab.bak
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null
fi
