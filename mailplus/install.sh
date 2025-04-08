#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon mailplus - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/bin/mailplus.sh" "/tmpRoot/usr/bin/mailplus.sh"
  mkdir -p "/tmpRoot/usr/arc/addons/mailplus"
  cp -prf "/addons/mailplus" "/tmpRoot/usr/arc/addons/"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/mailplus.service"
  {
    echo "[Unit]"
    echo "Description=addon mailplus"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/mailplus.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/mailplus.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/mailplus.service
}

uninstall_addon() {
  echo "Uninstalling addon mailplus - ${1}"
  # To-Do
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0