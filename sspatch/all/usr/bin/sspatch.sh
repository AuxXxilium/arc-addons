#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

copy_file() {
  SS_TARGET="${1}"
  SS_FILE="${2}"
  SS_INPUT="${3}"
  SS_MODE="${4}"
  if [ -f "${SS_INPUT}/${SS_FILE}" ] && [ -f "${SS_TARGET}/${SS_FILE}" ]; then
    SS_HASHIN
    SS_HASHIN="$(sha256sum "${SS_INPUT}/${SS_FILE}" | cut -d' ' -f1)"
    SS_HASHOUT
    SS_HASHOUT="$(sha256sum "${SS_TARGET}/${SS_FILE}" | cut -d' ' -f1)"
    if [ "${SS_HASHIN}" = "${SS_HASHOUT}" ]; then
      echo "sspatch: ${SS_FILE} already patched"
    else
      echo "sspatch: Patching ${SS_FILE}"
      rm -f "${SS_TARGET}/${SS_FILE}"
      cp -f "${SS_INPUT}/${SS_FILE}" "${SS_TARGET}/${SS_FILE}"
      chown SurveillanceStation:SurveillanceStation "${SS_TARGET}/${SS_FILE}"
      chmod "${SS_MODE}" "${SS_TARGET}/${SS_FILE}"
    fi
  fi
}

SSPATH="/var/packages/SurveillanceStation/target"
PATCHPATH="/usr/arc/addons/sspatch"
if [ -d "${SSPATH}" ]; then
  # Define the hosts entries to be added
  echo "sspatch: Adding hosts entries"
  ENTRIES=("0.0.0.0 synosurveillance.synology.com")
  for ENTRY in "${ENTRIES[@]}"; do
    if [ -f "/etc/hosts" ]; then
      # Check if the entry is already in the file
      if grep -Fxq "${ENTRY}" /etc/hosts; then
        echo "sspatch: Entry ${ENTRY} already exists"
      else
        echo "sspatch: Entry ${ENTRY} does not exist, adding now"
        echo "${ENTRY}" >> /etc/hosts
      fi
    fi
    if [ -f "/etc.defaults/hosts" ]; then
      if grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
        echo "sspatch: Entry ${ENTRY} already exists"
      else
        echo "sspatch: Entry ${ENTRY} does not exist, adding now"
        echo "${ENTRY}" >> /etc.defaults/hosts
      fi
    fi
  done

  SSVERSION
  SSVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
  SSMODEL
  SSMODEL="$(grep -oP '(?<=model=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)"
  
  if [ "${SSVERSION}" = "9.2.0-11289" ]; then
    [ "${SSMODEL}" = "synology_geminilake_dva1622" ] && SSVERSION="${SSVERSION}-openvino" || true
    [ "${SSMODEL}" = "synology_denverton_dva3221" ] && SSVERSION="${SSVERSION}-dva3221" || true
  fi
  
  mkdir -p "${PATCHPATH}/${SSVERSION}"
  tar -xzf "${PATCHPATH}/${SSVERSION}.tar.gz" -C "${PATCHPATH}/${SSVERSION}" > /dev/null 2>&1 || true
  SS_HASHIN
  SS_HASHIN="$(sha256sum "${PATCHPATH}/${SSVERSION}/libssutils.so" | cut -d' ' -f1)"
  SS_HASHOUT
  SS_HASHOUT="$(sha256sum "${SSPATH}/lib/libssutils.so" | cut -d' ' -f1)"
  
  if [ "${SS_HASHIN}" != "${SS_HASHOUT}" ]; then
    echo "sspatch: SurveillanceStation found - ${SSVERSION}"
    /usr/syno/bin/synopkg stop SurveillanceStation > /dev/null 2>&1 || true
  
    copy_file "${SSPATH}/lib" libssutils.so "${PATCHPATH}/${SSVERSION}" 0644
    copy_file "${SSPATH}/sbin" sscmshostd "${PATCHPATH}/${SSVERSION}" 0755
    copy_file "${SSPATH}/sbin" sscored "${PATCHPATH}/${SSVERSION}" 0755
    copy_file "${SSPATH}/sbin" ssdaemonmonitord "${PATCHPATH}/${SSVERSION}" 0755
    copy_file "${SSPATH}/sbin" ssexechelperd "${PATCHPATH}/${SSVERSION}" 0755
    copy_file "${SSPATH}/sbin" ssroutined "${PATCHPATH}/${SSVERSION}" 0755
    copy_file "${SSPATH}/sbin" ssmessaged "${PATCHPATH}/${SSVERSION}" 0755
    # copy_file "${SSPATH}/sbin" ssrtmpclientd "${PATCHPATH}/${SSVERSION}" 0755
  
    /usr/syno/bin/synopkg restart SurveillanceStation > /dev/null 2>&1 || true
  fi
else
  echo "sspatch: SurveillanceStation not found"
fi

exit 0