#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon vmmpatch - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/vmmpatch" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf "/usr/bin/vmmpatch.sh" "/tmpRoot/usr/bin/"
  cp -prf "/addons/vmmpatch" "/tmpRoot/usr/arc/addons/"

  # Create and configure systemd service
  cat >"/tmpRoot/usr/lib/systemd/system/vmmpatch.service" <<EOF
[Unit]
Description=addon vmmpatch
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/vmmpatch.sh

[Install]
WantedBy=multi-user.target
EOF

  # Create symlink for systemd service
  ln -vsf /usr/lib/systemd/system/vmmpatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmmpatch.service
}

uninstall_addon() {
  echo "Uninstalling addon vmmpatch - ${1}"
  # To-Do: Add uninstallation logic here
}

# Handle script arguments
case "${1}" in
  late) install_addon "${1}" ;;
  uninstall) uninstall_addon "${1}" ;;
esac
exit 0