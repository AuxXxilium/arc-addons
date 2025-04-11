#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon optional - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # libsynosata.so.1
  SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/8d15ba160000bf03000000e8c0c8ffff/8d15ba160000bf030000009090909090/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # libsynonvme.so.1
  SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/8d15ca400000bf03000000e820c3ffff/8d15ca400000bf030000009090909090/; s/8d15da1a0000bf03000000e8309dffff/8d15da1a0000bf030000009090909090/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # libhwcontrol.so.1
  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/8d1512840900bf03000000e8d0fcfdff/8D1512840900BF030000009090909090/; s/8d159a810900bf03000000e858fafdff/8D159A810900BF030000009090909090/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # syno-dump-core
  SH_FILE="/tmpRoot/usr/syno/sbin/syno-dump-core.sh"
  [ ! -f "${SH_FILE}.bak" ] && cp -pf "${SH_FILE}" "${SH_FILE}.bak"
  printf '#!/bin/sh\nexit 0\n' >"${SH_FILE}"
}

uninstall_addon() {
  echo "Uninstalling addon optional - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  SH_FILE="/tmpRoot/usr/syno/sbin/syno-dump-core.sh"
  [ -f "${SH_FILE}.bak" ] && mv -f "${SH_FILE}.bak" "${SH_FILE}"
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0