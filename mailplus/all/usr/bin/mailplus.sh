#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

copy_file() {
  MP_TARGET="${1}"
  MP_FILE="${2}"
  MP_INPUT="${3}"
  MP_MODE="${4}"
  if [ -f "${MP_INPUT}/${MP_FILE}" ] && [ -f "${MP_TARGET}/${MP_FILE}" ]; then
    local MP_HASHIN
    MP_HASHIN="$(sha256sum "${MP_INPUT}/${MP_FILE}" | cut -d' ' -f1)"
    local MP_HASHOUT
    MP_HASHOUT="$(sha256sum "${MP_TARGET}/${MP_FILE}" | cut -d' ' -f1)"
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

MPPATH="/var/packages/MailPlus-Server/target"
PATCHPATH="/usr/arc/addons/mailplus"
if [ -d "${MPPATH}" ]; then
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
        echo "${ENTRY}" >> /etc/hosts
      fi
    fi
    if [ -f "/etc.defaults/hosts" ]; then
      if grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
        echo "mailplus: Entry ${ENTRY} already exists"
      else
        echo "mailplus: Entry ${ENTRY} does not exist, adding now"
        echo "${ENTRY}" >> /etc.defaults/hosts
      fi
    fi
  done

  local MPVERSION
  MPVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/MailPlus-Server/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
  
  mkdir -p "${PATCHPATH}/${MPVERSION}"
  tar -xzf "${PATCHPATH}/${MPVERSION}.tar.gz" -C "${PATCHPATH}/${MPVERSION}" > /dev/null 2>&1 || true
  local MP_HASHIN
  MP_HASHIN="$(sha256sum "${PATCHPATH}/${MPVERSION}/libmailserver-license.so.1.0" | cut -d' ' -f1)"
  local MP_HASHOUT
  MP_HASHOUT="$(sha256sum "${MPPATH}/lib/libmailserver-license.so.1.0" | cut -d' ' -f1)"
  
  if [ "${MP_HASHIN}" != "${MP_HASHOUT}" ]; then
    echo "mailplus: MailPlus-Server found - ${MPVERSION}"
    /usr/syno/bin/synopkg stop MailPlus-Server > /dev/null 2>&1 || true
  
    copy_file "${MPPATH}/lib" libmailserver-license.so.1.0 "${PATCHPATH}/${MPVERSION}" 0755
  
    /usr/syno/bin/synopkg restart MailPlus-Server > /dev/null 2>&1 || true
  fi
else
  echo "mailplus: MailPlus-Server not found"
fi

exit 0