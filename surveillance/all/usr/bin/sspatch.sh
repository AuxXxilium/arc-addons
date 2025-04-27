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
    echo "sspatch: Patching ${TARGET_FILE}"
    FMODE="$(${ARCSU} stat -c "%a" "${TARGET_FILE}")"
    ${ARCSU} rm -f "${TARGET_FILE}"
    ${ARCSU} cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    ${ARCSU} chown SurveillanceStation:SurveillanceStation "${TARGET_FILE}"
    ${ARCSU} chmod "${FMODE}" "${TARGET_FILE}"
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
  case "$(${ARCSU} grep -oP '(?<=model=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)" in
  "synology_denverton_dva3219") SUFFIX="_dva3219" ;;
  "synology_denverton_dva3221") SUFFIX="_dva3221" ;;
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
        if ${ARCSU} grep -Fxq "${ENTRY}" /etc/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | ${ARCSU} tee -a /etc/hosts
        fi
      fi
      if [ -f "/etc.defaults/hosts" ]; then
        if ${ARCSU} grep -Fxq "${ENTRY}" /etc.defaults/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" | ${ARCSU} tee -a /etc.defaults/hosts
        fi
      fi
    done

    ${ARCSU} rm -rf "${SSPATCHPATH}/${SSVERSION}"
    ${ARCSU} mkdir -p "${SSPATCHPATH}/${SSVERSION}"
    ${ARCSU} tar -xzf "${SSPATCHPATH}/${SSVERSION}.tar.gz" -C "${SSPATCHPATH}/${SSVERSION}" > /dev/null 2>&1 || true

    PATCH_FILES=(
      "lib/libssutils.so"
      "lib/libssffmpegutils.so"
      "bin/ssctl"
      "sbin/ssactruled"
      "sbin/sscmshostd"
      "sbin/sscamerad"
      "sbin/sscored"
      "sbin/ssdaemonmonitord"
      "sbin/ssexechelperd"
      "sbin/ssroutined"
      "sbin/ssmessaged"
      "sbin/ssrtmpclientd"
      "webapi/Camera/src/SYNO.SurveillanceStation.Camera.so"
    )

    NEED_PATCH=false

    for F in "${PATCH_FILES[@]}"; do
      SOURCE_FILE="${SSPATCHPATH}/${SSVERSION}/${F}"
      TARGET_FILE="${SSPATH}/${F}"

      if [ -f "${SOURCE_FILE}" ] && [ -f "${TARGET_FILE}" ]; then
        HASH_SOURCE="$(${ARCSU} sha256sum "${SOURCE_FILE}" | cut -d' ' -f1)"
        HASH_TARGET="$(${ARCSU} sha256sum "${TARGET_FILE}" | cut -d' ' -f1)"

        if [ "${HASH_SOURCE}" != "${HASH_TARGET}" ]; then
          NEED_PATCH=true
          break
        fi
      else
        echo "sspatch: ${SOURCE_FILE} or ${TARGET_FILE} does not exist"
      fi
    done

    if [ "${NEED_PATCH}" = true ]; then
      echo "sspatch: Patching required, stopping SurveillanceStation"
      ${ARCSU} /usr/syno/bin/synopkg stop SurveillanceStation > /dev/null 2>&1 || true

      for F in "${PATCH_FILES[@]}"; do
        _process_file "${SSPATCHPATH}/${SSVERSION}/${F}" "${SSPATH}/${F}"
      done

      echo "sspatch: Restarting SurveillanceStation"
      ${ARCSU} /usr/syno/bin/synopkg restart SurveillanceStation > /dev/null 2>&1 || true
    else
      echo "sspatch: All files are already patched"
    fi
  fi
fi

exit 0