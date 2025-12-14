#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon addincards - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"

  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
  cp -pf "${FILE}" "${FILE}.tmp"
  : >"${FILE}"
  for N in $(grep '\[' "${FILE}.tmp" 2>/dev/null); do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
  rm -f "${FILE}.tmp"
  cp -pf "${FILE}" "/etc/etc.defaults/adapter_cards.conf"

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon addincards - ${1}"

  FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
  cp -pf "${FILE}" "/etc/etc.defaults/adapter_cards.conf"
fi