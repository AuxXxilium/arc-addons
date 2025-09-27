#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> && Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon virtiofs - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/bin/arc-virtiofs.sh /tmpRoot/usr/bin/arc-virtiofs.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/virtiofs.service"
  {
    echo "[Unit]"
    echo "Description=addon virtiofs daemon"
    echo "After=multi-user.target"
    echo "After=syno-volume.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=-/usr/bin/arc-virtiofs.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/virtiofs.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/virtiofs.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon virtiofs - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/virtiofs.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/virtiofs.service"

  rm -f /tmpRoot/usr/bin/arc-virtiofs.sh
fi
