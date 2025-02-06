#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_allowdowngrade() {
  echo "Installing addon allowdowngrade - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf /usr/bin/allowdowngrade.sh /tmpRoot/usr/bin/allowdowngrade.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  local DEST="/tmpRoot/usr/lib/systemd/system/allowdowngrade.service"
  {
    echo "[Unit]"
    echo "Description=addon allowdowngrade"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/allowdowngrade.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/allowdowngrade.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/allowdowngrade.service
}

uninstall_allowdowngrade() {
  echo "Uninstalling addon allowdowngrade - ${1}"
  # To-Do: Add uninstallation steps here
}

case "${1}" in
  late)
    install_allowdowngrade "${1}"
    ;;
  uninstall)
    uninstall_allowdowngrade "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac