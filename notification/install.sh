#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_notification() {
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
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/notification ${1} ${2}

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/notification.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service
}

uninstall_notification() {
  echo "Uninstalling addon notification - uninstall"
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service
  rm -f /tmpRoot/usr/lib/systemd/system/notification.service
  [ ! -f /tmpRoot/usr/arc/revert.sh ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/notification.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/notification.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "$1" in
  late) install_notification ${2:-false} ${3:-false} ;;
  uninstall) uninstall_notification ;;
esac