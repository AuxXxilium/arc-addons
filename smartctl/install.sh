#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon smartctl - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  FILE="/tmpRoot/usr/bin/smartctl"
  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
  
  cp -vpf /usr/bin/smartctl.sh "${FILE}"
}

uninstall_addon() {
  echo "Uninstalling addon smartctl - ${1}"

  FILE="/tmpRoot/usr/bin/smartctl"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
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