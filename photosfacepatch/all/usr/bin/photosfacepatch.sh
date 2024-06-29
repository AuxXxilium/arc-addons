#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"

if [ "${1}" = "-r" ]; then
  if [ -f "${SO_FILE}.bak" ]; then
    mv -f "${SO_FILE}.bak" "${SO_FILE}"
  fi
  exit
fi

if [ ! -f "${SO_FILE}" ]; then
  echo "SynologyPhotos not install"
  exit
fi

if [ ! -f "${SO_FILE}.bak" ]; then
  echo "Backup ${SO_FILE}"
  cp -vfp "${SO_FILE}" "${SO_FILE}.bak"
fi
echo "Patching ${SO_FILE}"
# support face and concept
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
# force to support concept
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
# force no Gpu
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
