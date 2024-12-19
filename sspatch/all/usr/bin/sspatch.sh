#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

function copy_file() {
  local target="${1}"
  local file="${2}"
  local input="${3}"
  local mode="${4}"
  if [ -f "${input}/${file}" ] && [ -f "${target}/${file}" ]; then
    echo "sspatch: Copying ${file} to ${target}"
    cp -f "${input}/${file}" "${target}/${file}"
    chown SurveillanceStation:SurveillanceStation "${target}/${file}"
    chmod "${mode}" "${target}/${file}"
  fi
}

SSPATH="/var/packages/SurveillanceStation/target"
PATCHPATH="/usr/arc/addons/sspatch"
if [ -d "${SSPATH}" ]; then
  SSVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)"
  SSMODEL="$(grep -oP '(?<=model=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)"
  if [ "${SSVERSION}" = "9.2.0-11289" ]; then
    [ "${SSMODEL}" = "synology_geminilake_dva1622" ] && SSVERSION="${SSVERSION}-dva1622" || true
    [ "${SSMODEL}" = "synology_denverton_dva3221" ] && SSVERSION="${SSVERSION}-dva3221" || true
  fi
  echo "sspatch: SurveillanceStation found - ${SSVERSION}"
  
  # Check Sha256sum for Patch
  CHECKSUM="$(sha256sum ${SSPATH}/lib/libssutils.so | cut -d' ' -f1)"
  PATCHCHECKSUM="$(sha256sum ${PATCHPATH}/${SSVERSION}/libssutils.so | cut -d' ' -f1)"
  [ "${CHECKSUM}" = "${PATCHCHECKSUM}" ] && SSPATCH="false" || SSPATCH="true"

  if [ "${SSPATCH}" = "true" ]; then
    echo "sspatch: patching required"
    /usr/syno/bin/synopkg stop SurveillanceStation
    sleep 5

    # Define the hosts entries to be added
    echo "sspatch: Adding hosts entries"
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")
    for ENTRY in "${ENTRIES[@]}"
    do
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

    copy_file ${SSPATH}/lib  libssutils.so    ${PATCHPATH}/${SSVERSION}  0644
    copy_file ${SSPATH}/sbin sscmshostd       ${PATCHPATH}/${SSVERSION}  0755
    copy_file ${SSPATH}/sbin sscored          ${PATCHPATH}/${SSVERSION}  0755
    copy_file ${SSPATH}/sbin ssdaemonmonitord ${PATCHPATH}/${SSVERSION}  0755
    copy_file ${SSPATH}/sbin ssexechelperd    ${PATCHPATH}/${SSVERSION}  0755
    copy_file ${SSPATH}/sbin ssroutined       ${PATCHPATH}/${SSVERSION}  0755
    copy_file ${SSPATH}/sbin ssmessaged       ${PATCHPATH}/${SSVERSION}  0755

    sleep 5
    /usr/syno/bin/synopkg restart SurveillanceStation
  else
    echo "sspatch: already patched"
  fi
else
  echo "sspatch: SurveillanceStation not found"
fi

exit 0