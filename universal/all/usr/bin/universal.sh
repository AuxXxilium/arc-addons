#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Check if /usr/bin/arcsu exists
ARCSU=""
if [ -x "/usr/bin/arcsu" ]; then
  ARCSU="/usr/bin/arcsu"
fi

#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Check if /usr/bin/arcsu exists
ARCSU=""
if [ -x "/usr/bin/arcsu" ]; then
  ARCSU="/usr/bin/arcsu"
fi

restore_synology_photos() {
  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  [ -f "${FILE}.bak" ] && ${ARCSU} mv -f "${FILE}.bak" "${FILE}"

  SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  [ -f "${SO_FILE}.bak" ] && ${ARCSU} mv -f "${SO_FILE}.bak" "${SO_FILE}"
}

patch_synology_photos() {
  echo "Stopping Synology Photos package..."
  ${ARCSU} /usr/syno/bin/synopkg stop SynologyPhotos > /dev/null 2>&1 || true

  FILE="/var/packages/SynologyPhotos/target/usr/bin/synofoto-bin-push-service"
  if [ -z "$(cat "/etc/application_key.conf")" ] && [ -f "${FILE}" ]; then
    [ ! -f "${FILE}.bak" ] && ${ARCSU} cp -pf "${FILE}" "${FILE}.bak"
    ${ARCSU} /usr/bin/killall "${FILE}" 2>/dev/null || true
    echo -e '#!/bin/sh\necho "key=304403268" > /etc/application_key.conf\nexit 0' | ${ARCSU} tee "${FILE}" >/dev/null
  fi

  SO_FILE="/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so.1.0"
  if [ -f "${SO_FILE}" ]; then
    [ ! -f "${SO_FILE}.bak" ] && ${ARCSU} cp -pf "${SO_FILE}" "${SO_FILE}.bak"
    ${ARCSU} PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
    ${ARCSU} PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
    ${ARCSU} PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
  fi

  echo "Restarting Synology Photos package..."
  ${ARCSU} /usr/syno/bin/synopkg restart SynologyPhotos > /dev/null 2>&1 || true
}

restore_surveillance_station() {
  [ -d "/var/packages/SurveillanceStation/target/@SSData/AddOns/LocalDisplay" ] &&
    ${ARCSU} rm -f "/volume1/@appstore/SurveillanceStation/@SSData/AddOns/LocalDisplay/disabled"
}

patch_surveillance_station() {
  echo "Stopping Surveillance Station package..."
  ${ARCSU} /usr/syno/bin/synopkg stop SurveillanceStation > /dev/null 2>&1 || true

  if [ -d "/var/packages/SurveillanceStation/target/@SSData/AddOns/LocalDisplay" ]; then
    echo -n "" | ${ARCSU} tee "/volume1/@appstore/SurveillanceStation/@SSData/AddOns/LocalDisplay/disabled" >/dev/null
    if [ -d "/var/packages/SurveillanceStation/target/local_display" ]; then
      ${ARCSU} rm -rf "/var/packages/SurveillanceStation/target/local_display/.config/chromium-local-display/BrowserMetrics/"*
    fi
  fi

  echo "Restarting Surveillance Station package..."
  ${ARCSU} /usr/syno/bin/synopkg restart SurveillanceStation > /dev/null 2>&1 || true
}

apply_all_patches() {
  echo "Applying all patches..."
  patch_synology_photos
  patch_surveillance_station
  echo "All patches applied successfully."
}

# Main entry point
case "${1}" in
  "restore")
    restore_synology_photos
    restore_surveillance_station
    ;;
  "patch-photos")
    patch_synology_photos
    ;;
  "patch-surveillance")
    patch_surveillance_station
    ;;
  "" | "all")
    apply_all_patches
    ;;
  *)
    echo "Usage: ${0} [restore | patch-photos | patch-surveillance | all]"
    echo "  restore            Restore original files"
    echo "  patch-photos       Apply patches for Synology Photos"
    echo "  patch-surveillance Apply patches for Surveillance Station"
    echo "  all                Apply all patches (default if no argument is provided)"
    exit 1
    ;;
esac

apply_all_patches() {
  echo "Applying all patches..."
  patch_synology_photos
  patch_surveillance_station
  echo "All patches applied successfully."
}

# Main entry point
case "${1}" in
  "restore")
    restore_synology_photos
    restore_surveillance_station
    ;;
  "patch-photos")
    patch_synology_photos
    ;;
  "patch-surveillance")
    patch_surveillance_station
    ;;
  "" | "all")
    apply_all_patches
    ;;
  *)
    echo "Usage: ${0} [restore | patch-photos | patch-surveillance | all]"
    echo "  restore            Restore original files"
    echo "  patch-photos       Apply patches for Synology Photos"
    echo "  patch-surveillance Apply patches for Surveillance Station"
    echo "  all                Apply all patches (default if no argument is provided)"
    exit 1
    ;;
esac