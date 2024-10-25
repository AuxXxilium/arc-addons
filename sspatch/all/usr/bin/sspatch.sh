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
  if [ -f "${input}/${file}" ]; then
    echo "sspatch: Copying ${file} to ${target}"
    mv -vf "${target}/${file}" "${target}/${file}".bak
    cp -vf "${input}/${file}" "${target}/${file}"
    chown SurveillanceStation:SurveillanceStation "${target}/${file}"
    chmod "${mode}" "${target}/${file}"
  else
    if [ "${file}" == "ssrtmpclientd" ]; then
      echo "sspatch: ${file} not found, skipping"
      return 0
    else
      echo "sspatch: ${file} not found, aborting"
      exit 1
    fi
  fi
}

SSPATH="/var/packages/SurveillanceStation/target"
PATCHPATH="/usr/arc"
if [ -d "${SSPATH}" ]; then
  echo "sspatch: SurveillanceStation found"
  
  # Define the hosts entries to be added
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

  /usr/syno/bin/synopkg stop SurveillanceStation
  sleep 5

  # Check Sha256sum for Patch
  [ -f "${SSPATH}/lib/libssutils.org.so" ] && CHECKSUM="$(sha256sum ${SSPATH}/lib/libssutils.org.so | cut -d' ' -f1)" || CHECKSUM="$(sha256sum ${SSPATH}/lib/libssutils.so | cut -d' ' -f1)"
  SSPATCH="false"
  if [ "${CHECKSUM}" = "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
    echo "sspatch: SurveillanceStation 9.2.0-11289"
    tar -zxf "${PATCHPATH}/sspatch.tgz" -C "${PATCHPATH}/"
    SSPATCH="true"
  elif [ "${CHECKSUM}" = "92a8c8c75446daa7328a34acc67172e1f9f3af8229558766dbe5804a86c08a5e" ]; then
    if [ -d "/var/packages/NVIDIARuntimeLibrary" ]; then
      echo "sspatch: SurveillanceStation DVA3221 9.2.0-11289"
      tar -zxf "${PATCHPATH}/sspatch-3221.tgz" -C "${PATCHPATH}/"
    else
      echo "sspatch: SurveillanceStation Openvino 9.2.0-11289"
      tar -zxf "${PATCHPATH}/sspatch-openvino.tgz" -C "${PATCHPATH}/"
    fi
    SSPATCH="true"
  else
    echo "sspatch: SurveillanceStation Version not supported"
    exit 0
  fi

  if [ "${SSPATCH}" == "true" ]; then
    copy_file ${SSPATH}/lib  libssutils.so    ${PATCHPATH}  0644
    copy_file ${SSPATH}/lib  libssutils.org.so    ${PATCHPATH}  0644
    copy_file ${SSPATH}/sbin sscmshostd       ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin sscored          ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin ssdaemonmonitord ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin ssexechelperd    ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin ssroutined       ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin ssmessaged       ${PATCHPATH}  0755
    copy_file ${SSPATH}/sbin ssrtmpclientd    ${PATCHPATH}  0755
  fi

  sleep 5
  /usr/syno/bin/synopkg restart SurveillanceStation
fi

exit 0