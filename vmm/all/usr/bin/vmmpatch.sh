#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

_process_file() {
  local SOURCE_FILE="${1}"
  local TARGET_FILE="${2}"
  local FMODE

  if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
    echo "vmmpatch: Patching ${TARGET_FILE}"
    FMODE="$(stat -c "%a" "${TARGET_FILE}")"
    rm -f "${TARGET_FILE}"
    cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    chown root:root "${TARGET_FILE}"
    chmod "${FMODE}" "${TARGET_FILE}"
  else
    echo "vmmpatch: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
  fi
}

VMMPATH="/var/packages/Virtualization/target"
VMMPATCHPATH="/usr/arc/addons/vmmpatch"
VMMVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/Virtualization/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"

if [ -z "${VMMVERSION}" ]; then
  echo "vmmpatch: Please install Virtualization first"
else
    rm -rf "${VMMPATCHPATH}/${VMMVERSION}"
    mkdir -p "${VMMPATCHPATH}/${VMMVERSION}"
    tar -xzf "${VMMPATCHPATH}/${VMMVERSION}.tar.gz" -C "${VMMPATCHPATH}/${VMMVERSION}" > /dev/null 2>&1 || true

    PATCH_FILES=(
      "usr/lib/libsynoccc.so"
    )
    NEED_PATCH=false

    for F in "${PATCH_FILES[@]}"; do
      SOURCE_FILE="${VMMPATCHPATH}/${VMMVERSION}/${F}"
      TARGET_FILE="${VMMPATH}/${F}"

      if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
        HASH_SOURCE="$(sha256sum "${SOURCE_FILE}" | cut -d' ' -f1)"
        HASH_TARGET="$(sha256sum "${TARGET_FILE}" | cut -d' ' -f1)"

        if [ "${HASH_SOURCE}" != "${HASH_TARGET}" ]; then
          NEED_PATCH=true
          break
        fi
      else
        echo "vmmpatch: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
      fi
    done

    if [ "${NEED_PATCH}" = true ]; then
      echo "vmmpatch: Patching required, stopping Virtualization"
      synopkg stop Virtualization > /dev/null 2>&1 || true

      for F in "${PATCH_FILES[@]}"; do
        _process_file "${VMMPATCHPATH}/${VMMVERSION}/${F}" "${VMMPATH}/${F}"
      done

      echo "vmmpatch: Restarting Virtualization"
      synopkg restart Virtualization > /dev/null 2>&1 || true
    else
      echo "vmmpatch: All files are already patched"
    fi
fi

exit 0