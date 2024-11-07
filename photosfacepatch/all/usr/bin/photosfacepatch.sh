#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

SO_FILE=$(find / -name "libsynophoto-plugin-platform.so.1.0" 2>/dev/null | head -1)

if [ -z "${SO_FILE}" ] || [ ! -f "${SO_FILE}" ]; then
  echo "SynologyPhotos not install"
  exit
fi

if [ "${1}" = "-r" ]; then
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"
  exit
fi

echo "Patching ${SO_FILE}"
[ ! -f "${SO_FILE}.bak" ] && cp -f "${SO_FILE}" "${SO_FILE}.bak"
# support face and concept
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
# force to support concept
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
# force no Gpu
PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"