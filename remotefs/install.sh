#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon remotefs - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  if [ -f "${SO_FILE}" ]; then
    echo "Patching libsynosdk.so.7"
    [ ! -f "${SO_FILE}.bak" ] && cp -f "${SO_FILE}" "${SO_FILE}.bak"
    # force to support remote fs
    PatchELFSharp "${SO_FILE}" "SYNOFSIsRemoteFS" "B8 00 00 00 00 C3"
  else
    echo "libsynosdk.so.7 not found"
  fi
}

uninstall_addon() {
  echo "Uninstalling addon remotefs - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
esac