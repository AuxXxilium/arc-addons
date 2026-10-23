#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
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

  /usr/bin/arc-backup.sh take "${FILE}"
  cp -pf "${FILE}" "${FILE}.tmp"
  : >"${FILE}"
  for N in $(grep '\[' "${FILE}.tmp" 2>/dev/null); do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
  rm -f "${FILE}.tmp"
  /usr/bin/arc-backup.sh seal "${FILE}"
  # POSIX-compliant way to replace /etc/ with /etc.defaults/ in the path
  FILE_DEFAULTS="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf"
  cp -pf "${FILE}" "${FILE_DEFAULTS}"

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon addincards - ${1}"

  FILE="/tmpRoot/usr/syno/etc/adapter_cards.conf"
  /usr/bin/arc-backup.sh restore "${FILE}"
  # POSIX-compliant way to replace /etc/ with /etc.defaults/ in the path
  FILE_DEFAULTS="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf"
  cp -pf "${FILE}" "${FILE_DEFAULTS}"
fi