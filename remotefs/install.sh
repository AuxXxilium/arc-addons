#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon remotefs - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  if [ -f "${SO_FILE}" ]; then
    echo "Patching libsynosdk.so.7"
    [ ! -f "${SO_FILE}.bak" ] && cp -f "${SO_FILE}" "${SO_FILE}.bak"
    # force to support remote fs
    PatchELFSharp "${SO_FILE}" "SYNOFSIsRemoteFS" "B8 00 00 00 00 C3"
  else
    echo "libsynosdk.so.7 not found"
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon remotefs - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"
fi