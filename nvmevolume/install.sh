#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# From：https://github.com/007revad/Synology_enable_M2_volume
# From: https://github.com/PeterSuh-Q3/tcrp-addons/blob/main/nvmevolume-onthefly/src/install.sh
#

if grep -q "nvmesystem" "/addons/addons.sh"; then
  echo "nvmevolume is not required if nvmesystem exists!"
  exit 0
fi

if [ "${1}" = "late" ]; then
  echo "Installing addon nvmevolume - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  SO_FILE="/tmpRoot/usr/lib64/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"

  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/803e00b801000000752.488b/803e00b8010000009090488b/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"
  chmod a+x "${SO_FILE}"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon nvmevolume - ${1}"

  SO_FILE="/tmpRoot/usr/lib64/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
fi