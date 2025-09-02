#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon notify - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/notify.sh /tmpRoot/usr/bin/notify.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/notify.service"
  {
    echo "[Unit]"
    echo "Description=arc notify"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/notify.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/notify.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notify.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon notify - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/notify.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/notify.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/notify.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/notify.sh" >>/tmpRoot/usr/arc/revert.sh
fi