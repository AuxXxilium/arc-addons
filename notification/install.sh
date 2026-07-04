#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon notification - late"
  mkdir -p /tmpRoot/usr/arc/addons/ /tmpRoot/usr/bin /tmpRoot/usr/lib/systemd/system/multi-user.target.wants

  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vpf /usr/bin/notification /tmpRoot/usr/bin/notification

  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/notification.service"
[Unit]
Description=notification daemon
After=synoscgi.service nginx.service

[Service]
Type=simple
Restart=always
ExecStartPre=/usr/bin/sleep 10
ExecStart=/usr/bin/notification "${2:-false}" "${3:-false}"

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/notification.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon notification - uninstall"
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service
  rm -f /tmpRoot/usr/lib/systemd/system/notification.service
  rm -f /tmpRoot/usr/bin/notification
fi