#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

function copy_file() {
  local target="${1}"
  local file="${2}"
  local input="${3}"
  local mode="${4}"

  mv -vf "${target}/${file}" "${target}/${file}".bak
  cp -vf "${input}/${file}" "${target}/${file}"
  chown SurveillanceStation:SurveillanceStation "${target}/${file}"
  chmod "${mode}" "${target}/${file}"
}

SSPATH="/var/packages/SurveillanceStation/target"
ADDONSPATH="/usr/arc"
if [ -d "${SSPATH}" ]; then
  # Define the hosts entries to be added
  ENTRIES=("0.0.0.0 synosurveillance.synology.com")
  for ENTRY in "${ENTRIES[@]}"
  do
    if [ -f "/tmpRoot/etc/hosts" ]; then
        # Check if the entry is already in the file
        if grep -Fxq "${ENTRY}" /tmpRoot/etc/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" >> /tmpRoot/etc/hosts
        fi
    fi
    if [ -f "/tmpRoot/etc.defaults/hosts" ]; then
        if grep -Fxq "${ENTRY}" /tmpRoot/etc.defaults/hosts; then
          echo "sspatch: Entry ${ENTRY} already exists"
        else
          echo "sspatch: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" >> /tmpRoot/etc.defaults/hosts
        fi
    fi
  done

  echo "sspatch: SurveillanceStation found"
  # Check Sha256sum for Patch
  CHECKSUM="$(sha256sum ${SSPATH}/lib/libssutils.so | cut -d' ' -f1)"
  if [ "${CHECKSUM}" == "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
    echo "sspatch: SurveillanceStation 9.2.0-11289"
    tar -zxf "${ADDONSPATH}/sspatch.tgz" -C "${ADDONSPATH}/"
    copy_file ${SSPATH}/lib  libssutils.so    ${ADDONSPATH}  0644
    copy_file ${SSPATH}/sbin sscmshostd       ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin sscored          ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssdaemonmonitord ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssexechelperd    ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssroutined       ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssrtmpclientd    ${ADDONSPATH}  0755
  elif [ "${CHECKSUM}" == "92a8c8c75446daa7328a34acc67172e1f9f3af8229558766dbe5804a86c08a5e" ]; then
    echo "sspatch: SurveillanceStation Openvino 9.2.0-11289"
    tar -zxf "${ADDONSPATH}/sspatch-openvino.tgz" -C "${ADDONSPATH}/"
    copy_file ${SSPATH}/lib  libssutils.so    ${ADDONSPATH}  0644
    copy_file ${SSPATH}/sbin sscmshostd       ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin sscored          ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssdaemonmonitord ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssexechelperd    ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssroutined       ${ADDONSPATH}  0755
    copy_file ${SSPATH}/sbin ssrtmpclientd    ${ADDONSPATH}  0755
  else
    echo "sspatch: SurveillanceStation version not supported"
  fi
fi

exit 0