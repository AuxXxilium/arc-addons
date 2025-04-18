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
  local MODE="${3}"

  if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
    echo "mailplus: Patching ${TARGET_FILE}"
    rm -f "${TARGET_FILE}"
    cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    chown MailPlus-Server:system "${TARGET_FILE}"
    chmod "${MODE}" "${TARGET_FILE}"
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
        if grep -Fxq "${ENTRY}" /etc/hosts; then
          echo "mailplus: Entry ${ENTRY} already exists"
        else
          echo "mailplus: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | tee -a /etc/hosts > /dev/null
        fi
      fi
      if [ -f "/etc.defaults/hosts" ]; then
        if grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
          echo "mailplus: Entry ${ENTRY} already exists"
        else
          echo "mailplus: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | tee -a /etc.defaults/hosts > /dev/null
        fi
      fi
    done

    rm -rf "${MPPATCHPATH}/${MPVERSION}"
    mkdir -p "${MPPATCHPATH}/${MPVERSION}"
    tar -xzf "${MPPATCHPATH}/${MPVERSION}.tar.gz" -C "${MPPATCHPATH}/${MPVERSION}" > /dev/null 2>&1 || true

    LIBMAILSERVER_SOURCE="${MPPATCHPATH}/${MPVERSION}/lib/libmailserver-license.so.1.0"
    LIBMAILSERVER_TARGET="${MPPATH}/lib/libmailserver-license.so.1.0"

    if [ -f "${LIBMAILSERVER_SOURCE}" ] && [ -f "${LIBMAILSERVER_TARGET}" ]; then
      HASH_SOURCE="$(sha256sum "${LIBMAILSERVER_SOURCE}" | cut -d' ' -f1)"
      HASH_TARGET="$(sha256sum "${LIBMAILSERVER_TARGET}" | cut -d' ' -f1)"

      if [ "${HASH_SOURCE}" != "${HASH_TARGET}" ]; then
        echo "mailplus: Patching"
        /usr/syno/bin/synopkg stop MailPlus-Server > /dev/null 2>&1 || true
      else
        echo "mailplus: Already patched"
        exit 0
      fi
    else
      echo "mailplus: ${LIBMAILSERVER_SOURCE} or ${LIBMAILSERVER_TARGET} does not exist"
      exit 0
    fi

    PATCH_FILES=(
      "lib/libmailserver-license.so.1.0"
    )

    for F in "${PATCH_FILES[@]}"; do
      _process_file "${MPPATCHPATH}/${MPVERSION}/${F}" "${MPPATH}/${F}" 0755
    done

    /usr/syno/bin/synopkg restart Perl > /dev/null 2>&1 || true
    /usr/syno/bin/synopkg restart MailPlus-Server > /dev/null 2>&1 || true
  fi
fi

exit 0