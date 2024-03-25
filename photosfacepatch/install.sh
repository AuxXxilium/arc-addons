#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon photosfacepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  if [ -f "${SO_FILE}" ]; then
    if [ ! -f "${SO_FILE}.bak" ]; then
      echo "Backup ${SO_FILE}"
      cp -vfp "${SO_FILE}" "${SO_FILE}.bak"
    fi
    echo "Patching libsynosdk.so.7"
    PatchELFSharp "${SO_FILE}" "SYNOFSIsRemoteFS" "B8 00 00 00 00 C3"
  else
    echo "libsynosdk.so.7 not found"
  fi
  SO_FILE="/tmpRoot/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so"
  if [ -f "${SO_FILE}" ]; then
    if [ ! -f "${SO_FILE}.bak" ]; then
      echo "Backup ${SO_FILE}"
      cp -vfp "${SO_FILE}" "${SO_FILE}.bak"
    fi
    echo "Patching ${${SO_FILE}}"
    # support face and concept
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform20IsSupportedIENetworkEv" "B8 00 00 00 00 C3"
    # force to support concept
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform18IsSupportedConceptEv" "B8 01 00 00 00 C3"
    # force no Gpu
    PatchELFSharp "${SO_FILE}" "_ZN9synophoto6plugin8platform23IsSupportedIENetworkGpuEv" "B8 00 00 00 00 C3"
  else
    echo "${SO_FILE} not found"
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon photosfacepatch - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynosdk.so.7"
  if [ -f "${SO_FILE}.bak" ]; then
    echo "Restore ${SO_FILE}"
    mv -f "${SO_FILE}.bak" "${SO_FILE}"
  fi
  SO_FILE="/tmpRoot/var/packages/SynologyPhotos/target/usr/lib/libsynophoto-plugin-platform.so"
  if [ -f "${SO_FILE}.bak" ]; then
    echo "Restore ${SO_FILE}"
    mv -f "${SO_FILE}.bak" "${SO_FILE}"
  fi
fi
