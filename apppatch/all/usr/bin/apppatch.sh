#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

patch_photos() {
  PHOTOS_PATH="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  if [ -z "$(cat "/etc/application_key.conf")" ] && [ -f "${PHOTOS_PATH}" ]; then
    [ ! -f "${PHOTOS_PATH}.bak" ] && cp -pf "${PHOTOS_PATH}" "${PHOTOS_PATH}.bak"
    /usr/bin/killall "${PHOTOS_PATH}" 2>/dev/null || true
    echo -e '#!/usr/bin/env sh\necho "key=304403268" > /etc/application_key.conf\nexit 0' >"${PHOTOS_PATH}"
  fi

  PHOTOS_SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  if [ -f "${PHOTOS_SO_FILE}" ]; then
    [ ! -f "${PHOTOS_SO_FILE}.bak" ] && cp -pf "${PHOTOS_SO_FILE}" "${PHOTOS_SO_FILE}.bak"
    # support face and concept
    PatchELFSharp "${PHOTOS_SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
    # force to support concept
    PatchELFSharp "${PHOTOS_SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
    # force no Gpu
    PatchELFSharp "${PHOTOS_SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
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

patch_hybridshare() {
  HS_PATH=/var/packages/HybridShare/target/ui/C2FS.js
  if [ -f "${HS_PATH}" ]; then
    [ ! -f "${HS_PATH}.bak" ] && cp -pf "${HS_PATH}" "${HS_PATH}.bak"
    sed -i 's/Beijing/Xeijing/' "${HS_PATH}"
    gzip -c "${HS_PATH}" >"${HS_PATH}.gz"
  fi
}

restore_all() {
  # Synology Photos
  PHOTOS_PATH="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  [ -f "${PHOTOS_PATH}.bak" ] && mv -f "${PHOTOS_PATH}.bak" "${PHOTOS_PATH}"

  PHOTOS_SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  [ -f "${PHOTOS_SO_FILE}.bak" ] && mv -f "${PHOTOS_SO_FILE}.bak" "${PHOTOS_SO_FILE}"

  # Surveillance Station -- local_display
  SS_PATH="/var/packages/SurveillanceStation/target"
  [ -d "${SS_PATH}/@SSData/AddOns/LocalDisplay" ] &&
    rm -f "${SS_PATH}/@SSData/AddOns/LocalDisplay/disabled"

  # HybridShare
  HS_PATH=/var/packages/HybridShare/target/ui/C2FS.js
  [ -f "${HS_PATH}.bak" ] && mv -f "${HS_PATH}.bak" "${HS_PATH}" && gzip -c "${HS_PATH}" >"${HS_PATH}.gz"
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
  hybridshare)
    patch_hybridshare
    ;;
  *)
    patch_photos
    patch_surveillance
    patch_hybridshare
    ;;
esac
exit 0