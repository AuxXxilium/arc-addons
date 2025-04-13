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
    local SS_HASHIN
    SS_HASHIN="$(sha256sum "${SS_INPUT}/${SS_FILE}" | cut -d' ' -f1)"
    local SS_HASHOUT
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
SSPATCHPATH="/usr/arc/addons/sspatch"
local SVERSION
SVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')"

if [ -z "${SVERSION}" ]; then
  echo "sspatch: Please install Surveillance Station first"
else
  SUFFIX=""
  case "$(grep -oP '(?<=model=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)" in
  "synology_denverton_dva3219") SUFFIX="_dva_3219" ;;
  "synology_denverton_dva3221") SUFFIX="_dva_3221" ;;
  "synology_geminilake_dva1622") SUFFIX="_openvino" ;;
  *) ;;
  esac
  
  local SSVERSION
  SSVERSION="${SVERSION}${SUFFIX}"

  if [ ! -f "${SSPATCHPATH}/${SSVERSION}.tar.gz" ]; then
    echo "sspatch: Patch for ${SSVERSION} not found"
  else
    echo "sspatch: Patch for ${SSVERSION} found"
    echo "sspatch: Adding hosts entries"
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")
    for ENTRY in "${ENTRIES[@]}"; do
      if [ -f "/etc/hosts" ]; then
        # Check if the entry is already in the file
        if grep -Fxq "${ENTRY}" /etc/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | tee -a /etc/hosts
        fi
      fi
      if [ -f "/etc.defaults/hosts" ]; then
        if grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | tee -a /etc.defaults/hosts
        fi
      fi
    done

    mkdir -p "${SSPATCHPATH}/${SSVERSION}"
    tar -xzf "${SSPATCHPATH}/${SSVERSION}.tar.gz" -C "${SSPATCHPATH}/${SSVERSION}" > /dev/null 2>&1 || true
    local SS_HASHIN
    SS_HASHIN=$(sha256sum "${SSPATCHPATH}/${SSVERSION}/libssutils.so" | awk '{print $1}')
    local SS_HASHOUT
    SS_HASHOUT=$(sha256sum "${SSPATH}/lib/libssutils.so" | awk '{print $1}')
    
    if [ "${SS_HASHIN}" != "${SS_HASHOUT}" ]; then
      echo "sspatch: SurveillanceStation found - ${SSVERSION}"
      /usr/syno/bin/synopkg stop SurveillanceStation > /dev/null 2>&1 || true
    
      copy_file "${SSPATH}/lib" libssutils.so "${SSPATCHPATH}/${SSVERSION}" 0644
      copy_file "${SSPATH}/sbin" sscmshostd "${SSPATCHPATH}/${SSVERSION}" 0755
      copy_file "${SSPATH}/sbin" sscored "${SSPATCHPATH}/${SSVERSION}" 0755
      copy_file "${SSPATH}/sbin" ssdaemonmonitord "${SSPATCHPATH}/${SSVERSION}" 0755
      copy_file "${SSPATH}/sbin" ssexechelperd "${SSPATCHPATH}/${SSVERSION}" 0755
      copy_file "${SSPATH}/sbin" ssroutined "${SSPATCHPATH}/${SSVERSION}" 0755
      copy_file "${SSPATH}/sbin" ssmessaged "${SSPATCHPATH}/${SSVERSION}" 0755
      # copy_file "${SSPATH}/sbin" ssrtmpclientd "${SSPATCHPATH}/${SSVERSION}" 0755
    
      /usr/syno/bin/synopkg restart SurveillanceStation > /dev/null 2>&1 || true
    fi
  fi
fi

exit 0