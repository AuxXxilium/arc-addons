#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_jrExit() {
  echo "Installing addon wol - jrExit"

  /usr/bin/wol.sh

}

install_late() {
  echo "Installing addon wol - late"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  [ ! -f "/tmpRoot/usr/bin/ethtool" ] && cp -pf /usr/bin/ethtool /tmpRoot/usr/bin/ethtool
  cp -pf /usr/bin/wol.sh /tmpRoot/usr/bin/wol.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/wol.service"
  {
    echo "[Unit]"
    echo "Description=Force WOL on ethN"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/wol.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/wol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service
}

uninstall_addon() {
  echo "Uninstalling addon wol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/wol.service"

  # rm -f /tmpRoot/usr/bin/ethtool
  rm -f /tmpRoot/usr/bin/wol.sh
}

case "${1}" in
  jrExit)
    install_jrExit
    ;;
  late)
    install_late
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
esac
exit 0