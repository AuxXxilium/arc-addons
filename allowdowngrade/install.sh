#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon allowdowngrade - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/allowdowngrade.sh /tmpRoot/usr/bin/allowdowngrade.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/allowdowngrade.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon allowdowngrade
After=multi-user.target

[Service]
User=root
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/allowdowngrade.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/allowdowngrade.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/allowdowngrade.service
fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon allowdowngrade - ${1}"
  # To-Do
fi