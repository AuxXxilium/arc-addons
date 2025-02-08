#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -e

install_addon() {
  echo "Installing addon optional - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # logger
  SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/8d15ba160000bf03000000e8c0c8ffff/8d15ba160000bf030000009090909090/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # syslog-ng
  if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf ]; then
    cp -pf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf.bak
    sed -i 's/destination(d_scemd)/flags(final)/g' /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf
  else
    echo "scemd.conf does not exist."
  fi

  if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf ]; then
    cp -pf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf.bak
    sed -i 's/destination(d_synosystemd)/flags(final)/g; s/destination(d_systemd)/flags(final)/g' /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf
  else
    echo "synosystemd.conf does not exist."
  fi
}

uninstall_addon() {
  echo "Uninstalling addon optional - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -pf "${SO_FILE}.bak" "${SO_FILE}"

  # Restore syslog-ng configurations
  if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf.bak ]; then
    mv -pf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf.bak /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf
  fi

  if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf.bak ]; then
    mv -pf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf.bak /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf
  fi
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