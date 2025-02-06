#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addincards() {
  echo "Installing addon addincards - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  local MODEL
  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  local FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"

  [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"
  cp -pf "${FILE}" "${FILE}.tmp"
  echo -n "" >"${FILE}"
  grep '\[' "${FILE}.tmp" | while read -r N; do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
  rm -f "${FILE}.tmp"
}

uninstall_addincards() {
  echo "Uninstalling addon addincards - ${1}"

  local FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
}

case "${1}" in
  late)
    install_addincards "${1}"
    ;;
  uninstall)
    uninstall_addincards "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac