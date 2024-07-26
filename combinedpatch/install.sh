#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon combinedpatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vf /usr/bin/combinedpatch.sh /tmpRoot/usr/bin/combinedpatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/combinedpatch.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon combinedpatch
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10s
ExecStartPre=/usr/bin/combinedpatch.sh
ExecStart=/usr/syno/bin/synopkg restart CodecPack

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/combinedpatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/combinedpatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon combinedpatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/combinedpatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/combinedpatch.service"
  rm -f "/tmpRoot/usr/bin/combinedpatch.sh"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/combinedpatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi
