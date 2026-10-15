#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Arc's notifications, a system addon: DSM's notification category for them,
# and the daemon that sends DSM's address after boot, a loader release once a
# day, and Arc Control's alerts - to DSM, and to the webhook and Discord when
# the loader has them on (${2} and ${3}, "false" when off). It took over the
# notify addon (the category) and the updatenotify addon (the release check).

if [ "${1}" = "late" ]; then
  echo "Installing addon notification - late"
  mkdir -p /tmpRoot/usr/arc/addons/ /tmpRoot/usr/bin /tmpRoot/usr/lib/systemd/system/multi-user.target.wants

  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vpf /usr/bin/notification /tmpRoot/usr/bin/notification
  cp -vpf /usr/bin/notification-templates.sh /tmpRoot/usr/bin/notification-templates.sh
  chmod +x /tmpRoot/usr/bin/notification-templates.sh

  # The settings the daemon and Arc Control share, one KEY=value per line.
  # The loader's configuration owns where notifications go, so those two lines
  # are rewritten from it at every boot; the rest is Arc Control's (which
  # alerts, their limits, DSM's own notifications) and is kept as it is.
  CONF="/tmpRoot/usr/arc/notification.conf"
  {
    printf 'WEBHOOK_URL=%s\n' "${2:-false}"
    printf 'DISCORD_ID=%s\n' "${3:-false}"
    # grep exits 1 when every line was one of the two, which is no failure.
    if [ -f "${CONF}" ]; then
      grep -v -e '^WEBHOOK_URL=' -e '^DISCORD_ID=' "${CONF}" || true
    fi
  } >"${CONF}.tmp" && mv -f "${CONF}.tmp" "${CONF}"
  chmod 600 "${CONF}"

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

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/notification-templates.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/notification-templates.sh" >>/tmpRoot/usr/arc/revert.sh
fi
