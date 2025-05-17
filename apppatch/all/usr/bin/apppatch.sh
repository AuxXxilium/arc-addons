#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "-r" ]; then
  # Synology Photos
  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"

  SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  # Surveillance Station -- local_display
  SS_PATH="/var/packages/SurveillanceStation/target"
  [ -d "${SS_PATH}/@SSData/AddOns/LocalDisplay" ] &&
    rm -f "${SS_PATH}/@SSData/AddOns/LocalDisplay/disabled"
else
  # Synology Photos
  # From: /usr/local/lib/systemd/system/pkg-SynologyPhotos-js-server.service
  #       synocloudserviceauth[27951]: cloudservice_register_api_key.cpp:293 Register api key failed: Invalid device info
  #       synocloudserviceauth[28129]: cloudservice_get_api_key.cpp:21 Cannot get key
  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  if [ -z "$(cat "/etc/application_key.conf")" ] && [ -f "${FILE}" ]; then
    [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
    /usr/bin/killall "${FILE}" 2>/dev/null || true
    echo -e '#!/bin/sh\necho "key=304403268" > /etc/application_key.conf\nexit 0' >"${FILE}"
  fi

  SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  if [ -f "${SO_FILE}" ]; then
    [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
    # support face and concept
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
    # force to support concept
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
    # force no Gpu
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
  fi

  # Surveillance Station -- local_display
  SS_PATH="/var/packages/SurveillanceStation/target"
  if [ -d "${SS_PATH}/@SSData/AddOns/LocalDisplay" ]; then
    echo -n "" >"${SS_PATH}/@SSData/AddOns/LocalDisplay/disabled"
    if [ -d "${SS_PATH}/local_display" ]; then
      rm -rf "${SS_PATH}/local_display/.config/chromium-local-display/BrowserMetrics/"*
    fi
  fi
fi