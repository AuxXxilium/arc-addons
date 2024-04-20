#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon addincards - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  FILE="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf"

  [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"

  cp -f "${FILE}" "${FILE}.tmp"
  echo -n "" >"${FILE}"
  for N in $(cat "${FILE}.tmp" 2>/dev/null | grep '\['); do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
  rm -f "${FILE}.tmp"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon addincards - ${1}"

  FILE="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
fi