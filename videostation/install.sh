#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon videostation - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/videostation.sh /tmpRoot/usr/bin/videostation.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/videostation.service"
  cat > ${DEST} <<EOF
[Unit]
Description=VideoStation for DSM
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/videostation.sh

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/videostation.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/videostation.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon videostation - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/videostation.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/videostation.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/videostation.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/videostation.sh" >> /tmpRoot/usr/arc/revert.sh
fi