#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon addincards - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  FILES="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf /tmpRoot/usr/syno/etc/adapter_cards.conf"

  for FILE in $FILES; do
    [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
    cp -pf "${FILE}" "${FILE}.tmp"
    : > "${FILE}"
    for N in $(grep '\[' "${FILE}.tmp" 2>/dev/null); do
      echo "${N}" >>"${FILE}"
      echo "${MODEL}=yes" >>"${FILE}"
    done
    rm -f "${FILE}.tmp"
  done
}

uninstall_addon() {
  echo "Uninstalling addon addincards - ${1}"

  FILES="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf /tmpRoot/usr/syno/etc/adapter_cards.conf"
  for FILE in $FILES; do
    [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
  done
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
esac