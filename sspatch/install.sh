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
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/bin/sspatch.sh" "/tmpRoot/usr/bin/sspatch.sh"

  cp -pf "/usr/lib/sspatch.tgz" "/tmpRoot/usr/arc/sspatch.tgz"
  cp -pf "/usr/lib/sspatch-openvino.tgz" "/tmpRoot/usr/arc/sspatch-openvino.tgz"
  cp -pf "/usr/lib/sspatch-3221.tgz" "/tmpRoot/usr/arc/sspatch-3221.tgz"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/sspatch.service"
  cat <<EOF >${DEST}
[Unit]
Description=addon sspatch
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/sspatch.sh

[Install]
WantedBy=multi-user.target
EOF
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/sspatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sspatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sspatch - ${1}"
  # To-Do
fi