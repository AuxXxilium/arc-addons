#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon apppatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/bin/PatchELFSharp /tmpRoot/usr/bin/PatchELFSharp
  cp -vpf /usr/bin/apppatch.sh /tmpRoot/usr/bin/apppatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  {
    echo "[Unit]"
    echo "Description=Arc apppatch daemon"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    # echo "ConditionPathExists=|/var/packages/SynologyPhotos"
    # echo "ConditionPathExists=|/var/packages/SurveillanceStation"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=no"
    echo "ExecStart=/usr/bin/apppatch.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"/tmpRoot/usr/lib/systemd/system/apppatch.service"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/apppatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.service

  {
    echo "[Unit]"
    echo "Description=Arc apppatch path"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    echo "ConditionPathExists=/var/packages"
    echo
    echo "[Path]"
    echo "PathModified=/var/packages"
    echo "Unit=apppatch.service"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"/tmpRoot/usr/lib/systemd/system/apppatch.path"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/apppatch.path /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.path

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon apppatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/apppatch.path"
  rm -f "/tmpRoot/usr/lib/systemd/system/apppatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/apppatch.path"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/apppatch.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/apppatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi