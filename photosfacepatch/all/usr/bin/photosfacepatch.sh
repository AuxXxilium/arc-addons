#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

SO_FILE1="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so"
SO_FILE2="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
if [ ! -f "${SO_FILE1}" ] && [ ! -f "${SO_FILE2}" ]; then
  echo "SynologyPhotos not installed -> Exit"
  exit
fi

if [ -f "${SO_FILE1}" ]; then
  if [ "${1}" = "-r" ]; then
    if [ -f "${SO_FILE1}.bak" ]; then
      mv -f "${SO_FILE1}.bak" "${SO_FILE1}"
    fi
    exit
  fi

  if [ ! -f "${SO_FILE1}.bak" ]; then
    echo "Backup ${SO_FILE1}"
    cp -vfp "${SO_FILE1}" "${SO_FILE1}.bak"
  fi

  echo "Patching ${SO_FILE1}"
  # support face and concept
  PatchELFSharp "${SO_FILE1}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
  # force to support concept
  PatchELFSharp "${SO_FILE1}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
  # force no Gpu
  PatchELFSharp "${SO_FILE1}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
fi

if [ -f "${SO_FILE2}" ]; then
  if [ "${1}" = "-r" ]; then
    if [ -f "${SO_FILE2}.bak" ]; then
      mv -f "${SO_FILE2}.bak" "${SO_FILE2}"
    fi
    exit
  fi

  if [ ! -f "${SO_FILE2}.bak" ]; then
    echo "Backup ${SO_FILE2}"
    cp -vfp "${SO_FILE2}" "${SO_FILE2}.bak"
  fi

  echo "Patching ${SO_FILE2}"
  # support face and concept
  PatchELFSharp "${SO_FILE2}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
  # force to support concept
  PatchELFSharp "${SO_FILE2}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
  # force no Gpu
  PatchELFSharp "${SO_FILE2}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
fi