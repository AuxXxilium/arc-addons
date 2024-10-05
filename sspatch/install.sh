#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon sspatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf "/usr/bin/sspatch.sh" "/tmpRoot/usr/bin/sspatch.sh"
  cp -vf "/usr/lib/sspatch.tgz" "/tmpRoot/usr/arc/sspatch.tgz"
  cp -vf "/usr/lib/sspatch-openvino.tgz" "/tmpRoot/usr/arc/sspatch-openvino.tgz"
  cp -vf "/usr/lib/sspatch-3221.tgz" "/tmpRoot/usr/arc/sspatch-3221.tgz"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/sspatch.service"
  cat <<EOF >${DEST}
[Unit]
Description=addon sspatch
After=multi-user.target
After=amepatch.service

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/bin/sspatch.sh

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/sspatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sspatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sspatch - ${1}"
  # To-Do
fi