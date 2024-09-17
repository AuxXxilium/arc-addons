#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon arcdns - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/arcdns.php /tmpRoot/usr/bin/arcdns.php
  cp -vf /usr/bin/arcdns.sh /tmpRoot/usr/bin/arcdns.sh
  
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arcdns.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon arcdns
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/arcdns.sh

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arcdns.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arcdns.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arcdns - ${1}"
  # To-Do
fi