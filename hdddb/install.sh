#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/007revad/Synology_HDD_db
#

if [ "${1}" = "late" ]; then
  echo "Installing addon hdddb - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/sbin/" "/tmpRoot/usr/syno/sbin/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/hdddb.sh /tmpRoot/usr/bin/hdddb.sh
  cp -pf /usr/sbin/dtc /tmpRoot/usr/sbin/dtc
  cp -pf /usr/syno/sbin/dhm_tool /tmpRoot/usr/syno/sbin/dhm_tool

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/hdddb.service"
[Unit]
Description=HDDs/SSDs drives databases
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/hdddb.sh -nrwpeSI

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/hdddb.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon hdddb - ${1}"

  # Remove systemd files
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service" \
        "/tmpRoot/usr/lib/systemd/system/hdddb.service"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  echo "/usr/bin/hdddb.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/hdddb.sh" >> /tmpRoot/usr/arc/revert.sh
fi