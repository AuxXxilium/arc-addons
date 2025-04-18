#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon sspatch - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/sspatch" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf "/usr/bin/sspatch.sh" "/tmpRoot/usr/bin/"
  cp -prf "/addons/sspatch" "/tmpRoot/usr/arc/addons/"

  # Create and configure systemd service
  cat >"/tmpRoot/usr/lib/systemd/system/sspatch.service" <<EOF
[Unit]
Description=addon sspatch
After=synoscgi.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/sspatch.sh

[Install]
WantedBy=multi-user.target
EOF

  # Create symlink for systemd service
  ln -vsf /usr/lib/systemd/system/sspatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sspatch.service
}

uninstall_addon() {
  echo "Uninstalling addon sspatch - ${1}"
  # To-Do: Add uninstallation logic here
}

# Handle script arguments
case "${1}" in
  late) install_addon "${1}" ;;
  uninstall) uninstall_addon "${1}" ;;
  *) exit 0 ;;
esac

exit 0