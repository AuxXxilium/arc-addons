#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon photosfacepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/PatchELFSharp /tmpRoot/usr/bin/PatchELFSharp
  cp -vf /usr/bin/photosfacepatch.sh /tmpRoot/usr/bin/photosfacepatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/photosfacepatch.service"
  cat <<EOF >${DEST}
[Unit]
Description=Enable face recognition in Synology Photos
After=syno-volume.target syno-space.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/photosfacepatch.sh

[Install]
WantedBy=multi-user.target
EOF

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/photosfacepatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/photosfacepatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon photosfacepatch - ${1}"

  rm -f /tmpRoot/usr/bin/PatchELFSharp

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/photosfacepatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/photosfacepatch.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/photosfacepatch.sh -r" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/photosfacepatch.sh" >> /tmpRoot/usr/arc/revert.sh
fi