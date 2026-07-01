#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# https://github.com/007revad/Synology_enable_M2_volume
# https://github.com/PeterSuh-Q3/tcrp-addons/blob/main/nvmevolume-onthefly/src/install.sh
#

if grep -wq "/addons/nvmesystem.sh" "/addons/addons.sh"; then
  echo "nvmevolume is not required if nvmesystem exists!"
  exit 0
fi

if [ "${1}" = "late" ]; then
  echo "Installing addon nvmevolume - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"

  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null \
    | sed "s/803e00b801000000752.488b/803e00b8010000009090488b/" \
    | xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  cat >"/tmpRoot/usr/bin/nvmevolume.sh" <<'SCRIPT'
#!/usr/bin/env sh
for F in /run/synostorage/disks/nvme*/m2_pool_support; do
  [ -e "${F}" ] || continue
  echo -n 1 >"${F}"
done
SCRIPT
  chmod +x "/tmpRoot/usr/bin/nvmevolume.sh"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  {
    echo "[Unit]"
    echo "Description=nvmevolume M.2 pool support flag"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=storagepanel.service"
    echo ""
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=-/usr/bin/nvmevolume.sh"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"/tmpRoot/usr/lib/systemd/system/nvmevolume.service"
  mkdir -p "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  ln -sf /usr/lib/systemd/system/nvmevolume.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmevolume.service

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon nvmevolume - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmevolume.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/nvmevolume.service"
  rm -f "/tmpRoot/usr/bin/nvmevolume.sh"
fi