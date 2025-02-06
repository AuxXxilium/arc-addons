#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# From：https://github.com/007revad/Synology_enable_M2_volume
# From: https://github.com/PeterSuh-Q3/tcrp-addons/blob/main/nvmevolume-onthefly/src/install.sh
#

if grep -wq "/addons/nvmesystem.sh" "/addons/addons.sh"; then
  echo "nvmevolume is not required if nvmesystem exists!"
  exit 0
fi

install_nvmevolume() {
  echo "Installing addon nvmevolume - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  local servicefiles=(
    "/tmpRoot/usr/lib/systemd/system/syno-detected-pool-scan.service"
    "/tmpRoot/usr/lib/systemd/system/syno-bootup-done.target.wants/syno-detected-pool-scan.service"
  )
  
  for file in "${servicefiles[@]}"; do
    if [ -f "$file" ]; then
      sed -i 's/After=syno-space.target syno-bootup-done.service syno-check-disk-compatibility.service/After=syno-space.target syno-bootup-done.service/' "$file"
      echo "Updated After directive in $file"
    else
      echo "File $file not found"
    fi
  done

  local SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"

  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/803e00b801000000752.488b/803e00b8010000009090488b/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"
}

uninstall_nvmevolume() {
  echo "Uninstalling addon nvmevolume - ${1}"

  local SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_nvmevolume "${1}"
    ;;
  uninstall)
    uninstall_nvmevolume "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac