#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon mailplus - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/mailplus" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf "/usr/bin/mailplus.sh" "/tmpRoot/usr/bin/"
  cp -prf "/addons/mailplus" "/tmpRoot/usr/arc/addons/"

  # Create and configure systemd service
  cat >"/tmpRoot/usr/lib/systemd/system/mailplus.service" <<EOF
[Unit]
Description=addon mailplus
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=-/usr/bin/mailplus.sh

[Install]
WantedBy=multi-user.target
EOF

  # Create symlink for systemd service
  ln -vsf /usr/lib/systemd/system/mailplus.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/mailplus.service
}

uninstall_addon() {
  echo "Uninstalling addon mailplus - ${1}"
  # To-Do: Add uninstallation logic here
}

# Handle script arguments
case "${1}" in
  late) install_addon "${1}" ;;
  uninstall) uninstall_addon "${1}" ;;
esac