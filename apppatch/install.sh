#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install() {
  echo "Installing addon apppatch patch - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/apppatch.sh /tmpRoot/usr/bin/

  # Create and configure systemd service
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/apppatch.service"
[Unit]
Description=apppatch addon daemon
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/bin/apppatch.sh

[Install]
WantedBy=multi-user.target
EOF
  ln -vsf /usr/lib/systemd/system/apppatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.service

  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/apppatch.path"
[Unit]
Description=apppatch addon path
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service
ConditionPathExists=/var/packages

[Path]
PathModified=/var/packages
Unit=apppatch.service

[Install]
WantedBy=multi-user.target
EOF
  ln -vsf /usr/lib/systemd/system/apppatch.path /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.path
}

uninstall() {
  echo "Uninstalling addon apppatch patch - ${1}"

  # Remove systemd files and symlinks
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.service
  rm -f /tmpRoot/usr/lib/systemd/system/apppatch.service

  # Create revert script if it doesn't exist
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  {
    echo "/usr/bin/apppatch.sh -r"
    echo "rm -f /usr/bin/apppatch.sh"
  } >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late) install "${1}" ;;
  uninstall) uninstall "${1}" ;;
  *) exit 0 ;;
esac

exit 0