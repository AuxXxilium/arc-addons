#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon diskcompat - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/diskcompat.sh /tmpRoot/usr/bin/diskcompat.sh

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/diskcompat.service"
[Unit]
Description=Disk compatibility database patcher
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service pkgctl-StorageManager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=-/usr/bin/diskcompat.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/diskcompat.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/diskcompat.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon diskcompat - ${1}"

  # Remove systemd files
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/diskcompat.service" \
        "/tmpRoot/usr/lib/systemd/system/diskcompat.service"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  echo "rm -f /usr/bin/diskcompat.sh" >> /tmpRoot/usr/arc/revert.sh
fi
