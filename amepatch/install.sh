#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon amepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/amepatch.sh /tmpRoot/usr/bin/amepatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/amepatch.service"
  {
    echo "[Unit]"
    echo "Description=addon amepatch"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/amepatch.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/amepatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon amepatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/amepatch.service"
  rm -f "/tmpRoot/usr/bin/amepatch.sh"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/amepatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi