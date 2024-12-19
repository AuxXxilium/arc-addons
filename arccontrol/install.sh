#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon arccontrol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/bin/arccontrol.sh" "/tmpRoot/usr/bin/arccontrol.sh"
  cp -pf "/addons/arc-control.spk" "/tmpRoot/usr/arc/addons/arc-control.spk"
  cp -pf "/addons/python-3.11.spk" "/tmpRoot/usr/arc/addons/python-3.11.spk"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arccontrol.service"
  {
    echo "[Unit]"
    echo "Description=addon arccontrol"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/arccontrol.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arccontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arccontrol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arccontrol - ${1}"
  # To-Do
fi