#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ ! "$(/bin/get_key_value /etc/synoinfo.conf supportportmappingv2)" = "yes" ]; then
   echo "non-DT models is not supported nvmesystem addon!"
   exit 0
 fi
# _BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"
# if [ ${_BUILD:-42218} -lt 42218 ]; then
#   echo "${_BUILD} is not supported nvmesystem addon!"
#   exit 0
# fi

if [ "${1}" = "early" ]; then
  echo "Installing addon nvmesystem - ${1}"

  # System volume is assembled with SSD Cache only, please remove SSD Cache and then reboot
  for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_ssd_cache" "no"; done

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -f "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/4584ed74b7488b4c24083b01/4584ed75b7488b4c24083b01/; s/4584f674b7488b4c24083b01/4584f675b7488b4c24083b01/;" | # P1: [69057,?); P2: [42218,69057);
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

elif [ "${1}" = "late" ]; then
  echo "Installing addon nvmesystem - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # disk/shared_disk_info_enum.c::84 Failed to allocate list in SharedDiskInfoEnum, errno=0x900.
  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/0f95c00fb6c0488b94240810/0f94c00fb6c0488b94240810/; s/8944240c8b44240809e84409/8944240c8b44240890904409/" | # [69057,?);     (from SA6400 69057)
    sed "s/0f95c00fb6c0488b94240810/0f94c00fb6c0488b94240810/; s/85e40f884e0100004585ed0f/85e49090909090904585ed0f/" | # [42962,69057); (from SA6400 42962)
    sed "s/0f95c00fb6c0488b4c242864/0f94c00fb6c0488b4c242864/; s/85e40f884e0100004585ed0f/85e49090909090904585ed0f/" | # [42962,69057); (from DS920+ 42962)
    sed "s/0f95c00fb6c04883c408c348/0f94c00fb6c04883c408c348/; s/85e40f88580100004585ed0f/85e49090909090904585ed0f/" | # [42218,42962); (from DS920+ 42218)
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # Create storage pool page without RAID type.
  cp -vpf /usr/bin/nvmesystem.sh /tmpRoot/usr/bin/nvmesystem.sh

  [ ! -f "/tmpRoot/usr/bin/gzip" ] && cp -vpf /usr/bin/gzip /tmpRoot/usr/bin/gzip

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/nvmesystem.service"
  {
    echo "[Unit]"
    echo "Description=nvmesystem daemon"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    echo "After=storagepanel.service" # storagepanel
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/nvmesystem.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/nvmesystem.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon nvmesystem - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/nvmesystem.service"

  # rm -f /tmpRoot/usr/bin/gzip
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/nvmesystem.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/nvmesystem.sh" >>/tmpRoot/usr/arc/revert.sh
fi
exit 0