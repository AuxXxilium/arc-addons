#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORMS="apollolake geminilake"
PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
if ! echo "${PLATFORMS}" | grep -qw "${PLATFORM}"; then
  echo "${PLATFORM} is not supported i915 addon!"
  exit 0
fi

if [ "${1}" = "patches" ]; then
  echo "Installing addon i915 - ${1}"

  if [ -n "${2}" ]; then
    GPU="$(echo "${2}" | sed 's/://g; s/.*/\L&/')"
  else
    GPU="$(lspci -n 2>/dev/null | grep 0300 | grep 8086 | cut -d' ' -f3 | sed 's/://g')"
    if [ -z "${GPU}" ]; then
      GPU="$(lspci -n 2>/dev/null | grep 0380 | grep 8086 | cut -d' ' -f3 | sed 's/://g')"
    fi
  fi
  [ -z "${GPU}" -o $(echo -n "${GPU}" | wc -c) -ne 8 ] && echo "GPU is not detected" && exit 0

  KO_FILE="/usr/lib/modules/i915.ko"
  [ ! -f "${KO_FILE}" ] && echo "i915.ko does not exist" && exit 0

  if [ -n "${2}" ] || grep -iq ${GPU} "/addons/i915ids" 2>/dev/null; then
    isLoad=0
    if lsmod 2>/dev/null | grep -q ^i915; then
      isLoad=1
      /usr/sbin/modprobe -r i915
    fi
    GPU_DEF="86800000923e0000"
    GPU_BIN="${GPU:2:2}${GPU:0:2}0000${GPU:6:2}${GPU:4:2}0000"
    echo "GPU:${GPU} GPU_BIN:${GPU_BIN}"
    cp -vf "${KO_FILE}" "${KO_FILE}.bak"
    cp -f "${KO_FILE}" "${KO_FILE}.tmp"
    xxd -c $(xxd -p "${KO_FILE}.tmp" 2>/dev/null | wc -c) -p "${KO_FILE}.tmp" 2>/dev/null |
      sed "s/${GPU_DEF}/${GPU_BIN}/; s/308201f706092a86.*70656e6465647e0a//" |
      xxd -r -p >"${KO_FILE}" 2>/dev/null
    rm -f "${KO_FILE}.tmp"
    [ "${isLoad}" = "1" ] && /usr/sbin/modprobe i915
  fi
elif [ "${1}" = "late" ]; then
  echo "Installing addon i915 - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  [ ! -f "${KO_FILE}.bak" ] && cp -vf "${KO_FILE}" "${KO_FILE}.bak"
  cp -vf "/usr/lib/modules/i915.ko" "${KO_FILE}"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon i915 - ${1}"

  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  [ -f "${KO_FILE}.bak" ] && mv -f "${KO_FILE}.bak" "${KO_FILE}"
fi