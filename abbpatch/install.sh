#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon abbpatch - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/abbpatch /tmpRoot/usr/bin/abbpatch

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/abbpatch.service"
[Unit]
Description=addon abbpatch
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/abbpatch

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/abbpatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/abbpatch.service
}

uninstall_addon() {
  echo "Uninstalling addon abbpatch - ${1}"

  # Remove systemd files and binaries
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/abbpatch.service" \
        "/tmpRoot/usr/lib/systemd/system/abbpatch.service"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert command
  echo "rm -f /usr/bin/abbpatch" >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late) install_addon "${1}" ;;
  uninstall) uninstall_addon "${1}" ;;
esac