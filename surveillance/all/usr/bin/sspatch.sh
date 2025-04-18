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
  local SUFFIX="${3}"
  local MODE="${4}"

  if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
    echo "sspatch: Patching ${TARGET_FILE}"
    rm -f "${TARGET_FILE}"
    cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    chown SurveillanceStation:SurveillanceStation "${TARGET_FILE}"
    chmod "${MODE}" "${TARGET_FILE}"
  else
    echo "sspatch: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
  fi
}

SSPATH="/var/packages/SurveillanceStation/target"
SSPATCHPATH="/usr/arc/addons/sspatch"
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

  SSVERSION="${SVERSION}${SUFFIX}"

  if [ ! -f "${SSPATCHPATH}/${SSVERSION}.tar.gz" ]; then
    echo "sspatch: Patch for ${SSVERSION} not found"
  else
    echo "sspatch: Patch for ${SSVERSION} found"
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")
    for ENTRY in "${ENTRIES[@]}"; do
      if [ -f "/etc/hosts" ]; then
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

    rm -rf "${SSPATCHPATH}/${SSVERSION}"
    mkdir -p "${SSPATCHPATH}/${SSVERSION}"
    tar -xzf "${SSPATCHPATH}/${SSVERSION}.tar.gz" -C "${SSPATCHPATH}/${SSVERSION}" > /dev/null 2>&1 || true

    LIBSSUTILS_SOURCE="${SSPATCHPATH}/${SSVERSION}/lib/libssutils.so"
    LIBSSUTILS_TARGET="${SSPATH}/lib/libssutils.so"

    if [ -f "${LIBSSUTILS_SOURCE}" ] && [ -f "${LIBSSUTILS_TARGET}" ]; then
      HASH_SOURCE="$(sha256sum "${LIBSSUTILS_SOURCE}" | cut -d' ' -f1)"
      HASH_TARGET="$(sha256sum "${LIBSSUTILS_TARGET}" | cut -d' ' -f1)"

      if [ "${HASH_SOURCE}" != "${HASH_TARGET}" ]; then
        echo "sspatch: Patching"
        /usr/syno/bin/synopkg stop SurveillanceStation > /dev/null 2>&1 || true
      else
        echo "sspatch: ${LIBSSUTILS_TARGET} already patched"
        exit 0
      fi
    else
      echo "sspatch: ${LIBSSUTILS_SOURCE} or ${LIBSSUTILS_TARGET} does not exist"
      exit 0
    fi

    PATCH_FILES=(
      "lib/libssutils.so"
      "bin/ssctl"
      "sbin/ssactruled"
      "sbin/sscmshostd"
      "sbin/sscored"
      "sbin/ssdaemonmonitord"
      "sbin/ssexechelperd"
      "sbin/ssroutined"
      "sbin/ssmessaged"
      "sbin/ssrtmpclientd"
      "webapi/Camera/src/SYNO.SurveillanceStation.Camera.so"
    )

    for F in "${PATCH_FILES[@]}"; do
      _process_file "${SSPATCHPATH}/${SSVERSION}/${F}" "${SSPATH}/${F}" 0755
    done

    /usr/syno/bin/synopkg restart SurveillanceStation > /dev/null 2>&1 || true
  fi
fi

exit 0