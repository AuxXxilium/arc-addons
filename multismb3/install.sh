#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Multi-SMB3"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vf /usr/bin/smb3-multi.sh /tmpRoot/usr/bin/smb3-multi.sh

  DEST="/tmpRoot/usr/lib/systemd/system/smb3-multi.service"
  cat <<EOF >${DEST}
[Unit]
Description=Enable Multi-SMB3

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/smb3-multi.sh

[Install]
WantedBy=multi-user.target
EOF

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/smb3-multi.service /tmpRoot/lib/systemd/system/multi-user.target.wants/smb3-multi.service
fi