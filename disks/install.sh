#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon disks - ${1}"

  /usr/bin/disks.sh --create

elif [ "${1}" = "late" ]; then
  echo "Installing addon disks - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # Patch libhwcontrol to allow NVMe as storage volume on nonDT models.
  # Skip if nvmesystem is present — it supersedes this with a full UI+lib patch.
  if ! grep -wq "/addons/nvmesystem.sh" "/addons/addons.sh"; then
    SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
    if [ -f "${SO_FILE}" ]; then
      [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
      cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
      xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null \
        | sed "s/803e00b801000000752.488b/803e00b8010000009090488b/" \
        | xxd -r -p >"${SO_FILE}" 2>/dev/null
      rm -f "${SO_FILE}.tmp"
      echo "disks addon: libhwcontrol patched for NVMe volume support"
    fi
  fi

  cp -vpf /usr/bin/disks.sh /tmpRoot/usr/bin/disks.sh
  {
    echo '# Author: "SynoCommunity"'
    echo ''
    echo '# general disks dtb rules'
    echo 'ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{DEVNAME}=="/dev/nvme*|/dev/sas*|/dev/usb*|/dev/sd*|/dev/sata*", PROGRAM=="/usr/bin/disks.sh --update %E{DEVNAME}"'
  } >"/tmpRoot/usr/lib/udev/rules.d/04-system-disk-dtb.rules"

  if [ "$(/bin/get_key_value "/etc.defaults/synoinfo.conf" "supportportmappingv2")" = "yes" ]; then
    cp -vpf /usr/bin/dtc /tmpRoot/usr/bin/dtc
    cp -vpf /etc/model.dtb /tmpRoot/etc/model.dtb
    cp -vpf /etc/model.dtb /tmpRoot/etc.defaults/model.dtb
    [ -f "/addons/model.dts" ] && cp -vpf /addons/model.dts /tmpRoot/etc/user_model.dts || rm -rf /tmpRoot/etc/user_model.dts
  else
    KVLIST="${KVLIST} usbportcfg esataportcfg eunitseq internalportcfg"

    cp -vpf /etc/extensionPorts /tmpRoot/etc/extensionPorts
    cp -vpf /etc/extensionPorts /tmpRoot/etc.defaults/extensionPorts
  fi
  KVLIST="${KVLIST} maxdisks supportnvme support_m2_pool" # support_ssd_cache support_write_cache"

  for K in ${KVLIST}; do
    V="$(/bin/get_key_value "/etc.defaults/synoinfo.conf" "${K}")"
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do
      /bin/set_key_value "${F}" "${K}" "${V}"
    done
    echo "disks addon: ${K}=${V}"
  done

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon disks - ${1}"

  rm -rf "/tmpRoot/usr/bin/disks.sh"
  rm -rf "/tmpRoot/usr/lib/udev/rules.d/04-system-disk-dtb.rules"
  rm -rf "/tmpRoot/usr/bin/dtc"
fi