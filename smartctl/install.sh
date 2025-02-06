#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_smartctl() {
  echo "Installing addon smartctl - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  local FILE="/tmpRoot/usr/bin/smartctl"
  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
  
  cp -vpf /usr/bin/smartctl.sh "${FILE}"
}

uninstall_smartctl() {
  echo "Uninstalling addon smartctl - ${1}"

  local FILE="/tmpRoot/usr/bin/smartctl"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
}

case "${1}" in
  late)
    install_smartctl "${1}"
    ;;
  uninstall)
    uninstall_smartctl "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac