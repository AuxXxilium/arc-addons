#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Arc's notifications, a system addon: DSM's notification category for them,
# and the daemon that sends DSM's address after boot, a loader release once a
# day, and Arc Control's alerts - to DSM, a webhook and Discord. It took over
# the notify addon (the category) and the updatenotify addon (the release
# check).
#
# Where they go is notification.conf, set in Arc Control and kept by DSM, not
# the loader's configuration: the loader's own webhook and Discord settings
# are for its messages before DSM runs, and are not passed in here.

if [ "${1}" = "late" ]; then
  echo "Installing addon notification - late"
  mkdir -p /tmpRoot/usr/arc/addons/ /tmpRoot/usr/bin /tmpRoot/usr/lib/systemd/system/multi-user.target.wants

  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vpf /usr/bin/notification /tmpRoot/usr/bin/notification
  cp -vpf /usr/bin/notification-templates.sh /tmpRoot/usr/bin/notification-templates.sh
  cp -vpf /usr/bin/notification-push.sh /tmpRoot/usr/bin/notification-push.sh
  chmod +x /tmpRoot/usr/bin/notification-templates.sh /tmpRoot/usr/bin/notification-push.sh

  # The settings the daemon and Arc Control share, one KEY=value per line,
  # Arc Control's to write. Kept as it is; without one the daemon uses its
  # defaults until Arc Control saves the first.
  CONF="/tmpRoot/usr/arc/notification.conf"
  [ -f "${CONF}" ] && chmod 600 "${CONF}"

  # After revert: on the first boot without the notify addon, revert runs its
  # uninstall, which removes the category the templates step registers. And
  # so after multi-user.target as well, as revert is - ordered after revert
  # but pulled in by the target without that, systemd would find a cycle.
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/notification.service"
[Unit]
Description=Arc notifications
Wants=synoscgi.service nginx.service
After=multi-user.target synoscgi.service nginx.service revert.service

[Service]
Type=simple
Restart=always
ExecStartPre=/usr/bin/sleep 10
ExecStartPre=-/usr/bin/notification-templates.sh
ExecStart=/usr/bin/notification

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/notification.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service

  # DSM's push registration, its own unit: it watches the first minutes after
  # boot, which must not hold up the daemon's boot message or anything else.
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/notification-push.service"
[Unit]
Description=Arc notifications: DSM push registration
Wants=synoscgi.service
After=multi-user.target synoscgi.service

[Service]
Type=simple
ExecStart=/usr/bin/notification-push.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/notification-push.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification-push.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon notification - uninstall"
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification.service
  rm -f /tmpRoot/usr/lib/systemd/system/notification.service
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notification-push.service
  rm -f /tmpRoot/usr/lib/systemd/system/notification-push.service
  rm -f /tmpRoot/usr/bin/notification /tmpRoot/usr/bin/notification-push.sh

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/notification-templates.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/notification-templates.sh" >>/tmpRoot/usr/arc/revert.sh
fi
