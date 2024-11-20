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
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/arcdns.php /tmpRoot/usr/bin/arcdns.php
  cp -pf /usr/bin/arcdns.sh /tmpRoot/usr/bin/arcdns.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arcdns.service"
  {
    echo "[Unit]"
    echo "Description=addon arcdns"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/arcdns.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arcdns.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arcdns.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arcdns - ${1}"
  # To-Do
fi