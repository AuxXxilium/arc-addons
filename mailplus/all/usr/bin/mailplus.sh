#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Check if /usr/bin/arcsu exists
ARCSU=""
if [ -x "/usr/bin/arcsu" ]; then
  ARCSU="/usr/bin/arcsu"
fi

_process_file() {
  local SOURCE_FILE="${1}"
  local TARGET_FILE="${2}"
  local FMODE

  if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
    echo "mailplus: Patching ${TARGET_FILE}"
    FMODE="$(${ARCSU} stat -c "%a" "${TARGET_FILE}")"
    ${ARCSU} rm -f "${TARGET_FILE}"
    ${ARCSU} cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    ${ARCSU} chown MailPlus-Server:system "${TARGET_FILE}"
    ${ARCSU} chmod "${FMODE}" "${TARGET_FILE}"
  else
    echo "mailplus: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
  fi
}

MPPATH="/var/packages/MailPlus-Server/target"
MPPATCHPATH="/usr/arc/addons/mailplus"
MPVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/MailPlus-Server/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"

if [ -z "${MPVERSION}" ]; then
  echo "mailplus: Please install MailPlus-Server first"
else
  if [ ! -f "${MPPATCHPATH}/${MPVERSION}.tar.gz" ]; then
    echo "mailplus: Patch for ${MPVERSION} not found"
  else
    echo "mailplus: Patch for ${MPVERSION} found"

    ENTRIES=("0.0.0.0 license.synology.com")
    for ENTRY in "${ENTRIES[@]}"; do
      if [ -f "/etc/hosts" ]; then
        if ${ARCSU} grep -Fxq "${ENTRY}" /etc/hosts; then
          echo "mailplus: Entry ${ENTRY} already exists"
        else
          echo "mailplus: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | ${ARCSU} tee -a /etc/hosts > /dev/null
        fi
      fi
      if [ -f "/etc.defaults/hosts" ]; then
        if ${ARCSU} grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
          echo "mailplus: Entry ${ENTRY} already exists"
        else
          echo "mailplus: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | ${ARCSU} tee -a /etc.defaults/hosts > /dev/null
        fi
      fi
    done

    ${ARCSU} rm -rf "${MPPATCHPATH}/${MPVERSION}"
    ${ARCSU} mkdir -p "${MPPATCHPATH}/${MPVERSION}"
    ${ARCSU} tar -xzf "${MPPATCHPATH}/${MPVERSION}.tar.gz" -C "${MPPATCHPATH}/${MPVERSION}" > /dev/null 2>&1 || true

    PATCH_FILES=(
      "lib/libmailserver-license.so.1.0"
    )

    NEED_PATCH=false

    for F in "${PATCH_FILES[@]}"; do
      SOURCE_FILE="${MPPATCHPATH}/${MPVERSION}/${F}"
      TARGET_FILE="${MPPATH}/${F}"

      if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
        HASH_SOURCE="$(${ARCSU} sha256sum "${SOURCE_FILE}" | cut -d' ' -f1)"
        HASH_TARGET="$(${ARCSU} sha256sum "${TARGET_FILE}" | cut -d' ' -f1)"

        if [ "${HASH_SOURCE}" != "${HASH_TARGET}" ]; then
          NEED_PATCH=true
          break
        fi
      else
        echo "mailplus: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
      fi
    done

    if [ "${NEED_PATCH}" = true ]; then
      echo "mailplus: Patching required, stopping MailPlus-Server"
      ${ARCSU} /usr/syno/bin/synopkg stop MailPlus-Server > /dev/null 2>&1 || true

      for F in "${PATCH_FILES[@]}"; do
        _process_file "${MPPATCHPATH}/${MPVERSION}/${F}" "${MPPATH}/${F}"
      done

      echo "mailplus: Restarting MailPlus-Server"
      ${ARCSU} /usr/syno/bin/synopkg restart Perl > /dev/null 2>&1 || true
      ${ARCSU} /usr/syno/bin/synopkg restart MailPlus-Server > /dev/null 2>&1 || true
    else
      echo "mailplus: All files are already patched"
    fi
  fi
fi

exit 0