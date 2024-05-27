#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

SO_FILE="/usr/lib/libsynosdk.so.7"

if [ "${1}" = "-r" ]; then
  if [ -f "${SO_FILE}.bak" ]; then
    mv -f "${SO_FILE}.bak" "${SO_FILE}"
  fi
  exit
fi

if [ ! -f "${SO_FILE}" ]; then
  echo "${SO_FILE} not found"
  exit
fi

if [ ! -f "${SO_FILE}.bak" ]; then
  echo "Backup ${SO_FILE}"
  cp -vfp "${SO_FILE}" "${SO_FILE}.bak"
fi
echo "Patching ${SO_FILE}"
PatchELFSharp "${SO_FILE}" "SYNOFSIsRemoteFS" "B8 00 00 00 00 C3"