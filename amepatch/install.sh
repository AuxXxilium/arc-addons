#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon amepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vf /usr/bin/amepatch.sh /tmpRoot/usr/bin/amepatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/amepatch.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon amepatch
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10s
RemainAfterExit=yes
ExecStartPre=/usr/bin/amepatch.sh
ExecStart=/usr/syno/bin/synopkg restart CodecPack

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/amepatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service

    # Cleanup codecpatch
    [ -f "/tmpRoot/usr/bin/codecpatch.sh" ] && rm -f "/tmpRoot/usr/bin/codecpatch.sh"
    [ -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service" ] && rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service"
    [ -f "/tmpRoot/usr/lib/systemd/system/codecpatch.service" ] && rm -f "/tmpRoot/usr/lib/systemd/system/codecpatch.service"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon amepatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/amepatch.service"
  rm -f "/tmpRoot/usr/bin/amepatch.sh"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/amepatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi
