#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_lsiutil() {
  echo "Installing addon lsiutil - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/sbin/lsiutil /tmpRoot/usr/sbin/lsiutil
}

uninstall_lsiutil() {
  echo "Uninstalling addon lsiutil - ${1}"
  rm -f "/tmpRoot/usr/sbin/lsiutil"
}

case "${1}" in
  late)
    install_lsiutil "${1}"
    ;;
  uninstall)
    uninstall_lsiutil "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac