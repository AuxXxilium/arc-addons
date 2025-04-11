#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install() {
  echo "Installing addon universal patch - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vpf /usr/bin/{PatchELFSharp,sveinstaller,universal.sh} /tmpRoot/usr/bin/

  # Create and configure systemd service
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  cat >"/tmpRoot/usr/lib/systemd/system/universal.service" <<EOF
[Unit]
Description=universal patch daemon
After=syno-packages.target

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=-/usr/bin/universal.sh

[Install]
WantedBy=multi-user.target
EOF

  # Create and configure systemd path
  cat >"/tmpRoot/usr/lib/systemd/system/universal.path" <<EOF
[Unit]
Description=universal patch daemon path
After=syno-packages.target
ConditionPathExists=/var/packages

[Path]
PathModified=/var/packages
Unit=universal.service

[Install]
WantedBy=multi-user.target
EOF

  # Create symlinks for systemd
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/universal.{service,path} /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/
}

uninstall() {
  echo "Uninstalling addon universal patch - ${1}"

  # Remove systemd files and symlinks
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/universal.{service,path}
  rm -f /tmpRoot/usr/lib/systemd/system/universal.{service,path}

  # Create revert script if it doesn't exist
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  {
    echo "/usr/bin/universal.sh -r"
    echo "rm -f /usr/bin/universal.sh"
  } >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late) install "${1}" ;;
  uninstall) uninstall "${1}" ;;
  *) exit 0 ;;
esac

exit 0