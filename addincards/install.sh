#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon addincards - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"

  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
  cp -pf "${FILE}" "${FILE}.tmp"
  : > "${FILE}"
  for N in $(grep '\[' "${FILE}.tmp" 2>/dev/null); do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
  rm -f "${FILE}.tmp"
}

uninstall_addon() {
  echo "Uninstalling addon addincards - ${1}"

  FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
esac