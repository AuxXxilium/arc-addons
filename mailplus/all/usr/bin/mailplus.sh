#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

copy_file() {
  local MP_TARGET
  local MP_FILE
  local MP_INPUT
  local MP_MODE
  local MP_HASHIN
  local MP_HASHOUT
  MP_TARGET="${1}"
  MP_FILE="${2}"
  MP_INPUT="${3}"
  if [ -f "${MP_INPUT}/${MP_FILE}" ] && [ -f "${MP_TARGET}/${MP_FILE}" ]; then
    MP_MODE="$(stat -c "%a" "${MP_TARGET}/${MP_FILE}")"
    MP_HASHIN="$(sha256sum "${MP_INPUT}/${MP_FILE}" | awk '{print $1}')"
    MP_HASHOUT="$(sha256sum "${MP_TARGET}/${MP_FILE}" | awk '{print $1}')"
    if [ "${MP_HASHIN}" = "${MP_HASHOUT}" ]; then
      echo "mailplus: ${MP_FILE} already patched"
    else
      echo "mailplus: Patching ${MP_FILE}"
      rm -f "${MP_TARGET}/${MP_FILE}"
      cp -f "${MP_INPUT}/${MP_FILE}" "${MP_TARGET}/${MP_FILE}"
      chown MailPlus-Server:system "${MP_TARGET}/${MP_FILE}"
      chmod "${MP_MODE}" "${MP_TARGET}/${MP_FILE}"
    fi
  fi
}

local MPPATCH
MPPATH="/var/packages/MailPlus-Server/target"
local MPPATCHPATH
MPPATCHPATH="/usr/arc/addons/mailplus"
local MPVERSION
MPVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/MailPlus-Server/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"

if [ -z "${MPVERSION}" ]; then
  echo "mailplus: Please install MailPlus-Server first"
else
  if [ ! -f "${MPPATCHPATH}/${MPVERSION}.tar.gz" ]; then
    echo "mailplus: Patch for ${MPVERSION} not found"
  else
    # Define the hosts entries to be added
    echo "mailplus: Adding hosts entries"
    ENTRIES=("0.0.0.0 license.synology.com")
    for ENTRY in "${ENTRIES[@]}"; do
      if [ -f "/etc/hosts" ]; then
        # Check if the entry is already in the file
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
    
    mkdir -p "${MPPATCHPATH}/${MPVERSION}"
    tar -xzf "${MPPATCHPATH}/${MPVERSION}.tar.gz" -C "${MPPATCHPATH}/${MPVERSION}" > /dev/null 2>&1 || true
    local MP_HASHIN
    MP_HASHIN="$(sha256sum "${MPPATCHPATH}/${MPVERSION}/libmailserver-license.so.1.0" | awk '{print $1}')"
    local MP_HASHOUT
    MP_HASHOUT="$(sha256sum "${MPPATH}/lib/libmailserver-license.so.1.0" | awk '{print $1}')"
    
    if [ "${MP_HASHIN}" != "${MP_HASHOUT}" ]; then
      echo "mailplus: MailPlus-Server found - ${MPVERSION}"
      /usr/syno/bin/synopkg stop MailPlus-Server > /dev/null 2>&1 || true
    
      copy_file "${MPPATH}/lib" "libmailserver-license.so.1.0" "${MPPATCHPATH}/${MPVERSION}"
    
      /usr/syno/bin/synopkg restart Perl > /dev/null 2>&1 || true
      /usr/syno/bin/synopkg restart MailPlus-Server > /dev/null 2>&1 || true
    fi
  fi
fi

exit 0