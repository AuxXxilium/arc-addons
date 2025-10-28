#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORMS="apollolake geminilake"
PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d '_' -f2)"

# Validate platform
if [ -z "${PLATFORM}" ]; then
  echo "Error: Unable to detect platform."
  exit 1
fi

if ! echo "${PLATFORMS}" | grep -wq "${PLATFORM}"; then
  echo "Error: ${PLATFORM} is not supported by the i915 addon!"
  exit 1
fi

# Handle "patches" argument
if [ "${1}" = "patches" ]; then
  echo "Installing addon i915 - ${1}"

  # Detect GPU
  GPU="$(lspci -nd ::300 2>/dev/null | grep 8086 | head -1 | cut -d ' ' -f3 | sed 's/://g')"
  if [ -f "/addons/i915ids" ]; then
    grep -iq "${GPU}" "/addons/i915ids" 2>/dev/null || GPU=""
  else
    echo "Warning: /addons/i915ids not found. Skipping GPU validation."
    GPU=""
  fi

  # Validate GPU
  if [ -z "${GPU}" ] || [ "$(printf "%b" "${GPU}" | wc -c)" -ne 8 ]; then
    echo "Error: GPU is not detected or invalid."
    exit 1
  fi

  # Validate kernel module file
  KO_FILE="/usr/lib/modules/i915.ko"
  if [ ! -f "${KO_FILE}" ]; then
    echo "Error: i915.ko does not exist."
    exit 1
  fi

  # Unload i915 module if loaded
  isLoad=0
  if lsmod 2>/dev/null | grep -q "^i915"; then
    isLoad=1
    if ! timeout 10 /usr/sbin/modprobe -r i915; then
      echo "Error: Failed to unload i915 module."
      exit 1
    fi
  fi

  # Patch the kernel module
  GPU_DEF="86800000923e0000"
  GPU_BIN="$(echo "${GPU}" | cut -c3-4)$(echo "${GPU}" | cut -c1-2)0000$(echo "${GPU}" | cut -c7-8)$(echo "${GPU}" | cut -c5-6)0000"
  echo "GPU: ${GPU}, GPU_BIN: ${GPU_BIN}"

  cp -pf "${KO_FILE}" "${KO_FILE}.tmp"
  if ! xxd -c "$(xxd -p "${KO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${KO_FILE}.tmp" 2>/dev/null |
    sed "s/${GPU_DEF}/${GPU_BIN}/; s/308201f706092a86.*70656e6465647e0a//" |
    xxd -r -p >"${KO_FILE}" 2>/dev/null; then
    echo "Error: Failed to patch i915.ko."
    exit 1
  fi
  rm -f "${KO_FILE}.tmp"

  # Reload i915 module if it was previously loaded
  if [ "${isLoad}" = "1" ]; then
    if ! /usr/sbin/modprobe i915; then
      echo "Error: Failed to reload i915 module."
      exit 1
    fi
  fi

# Handle "late" argument
elif [ "${1}" = "late" ]; then
  echo "Installing addon i915 - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  if [ ! -f "${KO_FILE}.bak" ]; then
    cp -pf "${KO_FILE}" "${KO_FILE}.bak"
  fi
  cp -vpf "/usr/lib/modules/i915.ko" "${KO_FILE}"

# Handle "uninstall" argument
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon i915 - ${1}"

  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  if [ -f "${KO_FILE}.bak" ]; then
    mv -f "${KO_FILE}.bak" "${KO_FILE}"
  fi
fi