#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_optional() {
  echo "Installing addon optional - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # logger
  local SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/8d15ba160000bf03000000e8c0c8ffff/8d15ba160000bf030000009090909090/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"
}

uninstall_optional() {
  echo "Uninstalling addon optional - ${1}"

  local SO_FILE="/tmpRoot/usr/lib/libsynosata.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -pf "${SO_FILE}.bak" "${SO_FILE}"

  # syslog-ng
  local conf_files=(
    "/tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf"
    "/tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf"
  )

  for conf_file in "${conf_files[@]}"; do
    if [ -f "${conf_file}" ]; then
      cp -pf "${conf_file}" "${conf_file}.bak"
      if [ "${conf_file}" = "/tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf" ]; then
        sed -i 's/destination(d_scemd)/flags(final)/g' "${conf_file}"
      elif [ "${conf_file}" = "/tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf" ]; then
        sed -i 's/destination(d_synosystemd)/flags(final)/g; s/destination(d_systemd)/flags(final)/g' "${conf_file}"
      fi
    else
      echo "${conf_file} does not exist."
    fi
  done
}

case "${1}" in
  late)
    install_optional "${1}"
    ;;
  uninstall)
    uninstall_optional "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac