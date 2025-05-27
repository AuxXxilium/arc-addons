#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

patch_photos() {
  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  if [ -z "$(cat "/etc/application_key.conf")" ] && [ -f "${FILE}" ]; then
    [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
    /usr/bin/killall "${FILE}" 2>/dev/null || true
    echo -e '#!/usr/bin/env sh\necho "key=304403268" > /etc/application_key.conf\nexit 0' >"${FILE}"
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
}

patch_surveillance() {
  SS_PATH="/var/packages/SurveillanceStation/target"
  if [ -d "${SS_PATH}/@SSData/AddOns/LocalDisplay" ]; then
    echo -n "" >"${SS_PATH}/@SSData/AddOns/LocalDisplay/disabled"
    if [ -d "${SS_PATH}/local_display" ]; then
      rm -rf "${SS_PATH}/local_display/.config/chromium-local-display/BrowserMetrics/"*
    fi
  fi
}

restore_all() {
  # Synology Photos
  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"

  SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  # Surveillance Station -- local_display
  SS_PATH="/var/packages/SurveillanceStation/target"
  [ -d "${SS_PATH}/@SSData/AddOns/LocalDisplay" ] &&
    rm -f "${SS_PATH}/@SSData/AddOns/LocalDisplay/disabled"
}

case "$1" in
  -r)
    restore_all
    ;;
  surveillance)
    patch_surveillance
    ;;
  photosface)
    patch_photos
    ;;
  *)
    patch_photos
    patch_surveillance
    ;;
esac
exit 0