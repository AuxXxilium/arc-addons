#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon ups - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  FILE="/tmpRoot/usr/syno/bin/synoups"
  [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"

  sed -i 's|/usr/syno/sbin/synopoweroff.*$|/usr/syno/sbin/synopoweroff|g' "${FILE}"
  
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ups - ${1}"

  FILE="/tmpRoot/usr/syno/bin/synoups"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
fi
