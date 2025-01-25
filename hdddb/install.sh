#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# From：https://github.com/007revad/Synology_HDD_db
# 

if [ "${1}" = "late" ]; then
  echo "Installing addon hdddb - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/hdddb.sh /tmpRoot/usr/bin/hdddb.sh
  cp -pf /usr/sbin/dtc /tmpRoot/usr/sbin/dtc
  cp -pf /usr/syno/sbin/dhm_tool /tmpRoot/usr/syno/sbin/dhm_tool

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/hdddb.service"
  cat <<EOF >"${DEST}"
[Unit]
Description=HDDs/SSDs drives databases
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/hdddb.sh -nweSI

[Install]
WantedBy=multi-user.target
EOF
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/hdddb.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon hdddb - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/hdddb.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/hdddb.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/hdddb.sh" >> /tmpRoot/usr/arc/revert.sh
fi