#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# From：https://github.com/007revad/Synology_enable_Deduplication
#

install_addon() {
  echo "Installing deduplication addon"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/deduplication.sh /tmpRoot/usr/bin/

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/deduplication.service"
[Unit]
Description=Enable Deduplication
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=-/usr/bin/deduplication.sh -t

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/deduplication.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service
}

uninstall_addon() {
  echo "Uninstalling deduplication addon"

  # Remove systemd files
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service" \
        "/tmpRoot/usr/lib/systemd/system/deduplication.service"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  echo "/usr/bin/deduplication.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/deduplication.sh" >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late) install_addon ;;
  uninstall) uninstall_addon ;;
esac