#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon expands - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/expands.sh /tmpRoot/usr/bin/expands.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/expands.service"
  {
    echo "[Unit]"
    echo "Description=Expanded miscellaneous"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/expands.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/expands.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/expands.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon expands - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/expands.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/expands.service"

  FILE="/tmpRoot/usr/syno/etc/usb.map"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
  FILE="/tmpRoot/etc/ssl/certs/ca-certificates.crt"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
fi
