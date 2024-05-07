#!/usr/bin/env ash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
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
    if [ ! -f "${SO_FILE}.bak" ]; then
      echo "Backup ${SO_FILE}"
      cp -vfp "${SO_FILE}" "${SO_FILE}.bak"
    fi
    echo "Patching libsynosdk.so.7"
    PatchELFSharp "${SO_FILE}" "SYNOFSIsRemoteFS" "B8 00 00 00 00 C3"
  else
    echo "libsynosdk.so.7 not found"
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon remotefs - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  if [ -f "${SO_FILE}.bak" ]; then
    echo "Restore ${SO_FILE}"
    mv -f "${SO_FILE}.bak" "${SO_FILE}"
  fi
fi
