#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon storagepanel - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/storagepanel.sh /tmpRoot/usr/bin/storagepanel.sh
  [ ! -f "/tmpRoot/usr/bin/gzip" ] && cp -pf /usr/bin/gzip /tmpRoot/usr/bin/gzip

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/storagepanel.service"
  {
    echo "[Unit]"
    echo "Description=Modify storage panel"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/storagepanel.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/storagepanel.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/storagepanel.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon storagepanel - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/storagepanel.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/storagepanel.service"

  # rm -f /tmpRoot/usr/bin/gzip
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/storagepanel.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/storagepanel.sh" >>/tmpRoot/usr/arc/revert.sh
fi