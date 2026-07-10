#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon disks - ${1}"

  # Apply user-supplied supportsas override from /addons/synoinfo.conf before disk
  # enumeration runs. Without this, SAS-HBA-based models on AHCI environments (e.g.
  # an SAS-HBA model on VMware) fail to enumerate any disk because the
  # /sys/class/sas_host/* glob synodiskd relies on stays empty until supportsas is set.
  # Only apply it when a SCSI/RAID/SAS-class controller is present - setting supportsas
  # on a system with none of these has no benefit. PCI class code alone can't reliably
  # distinguish "will register a sas_host" from "won't": many real SAS HBAs (LSI/
  # Broadcom mpt3sas, megaraid_sas) advertise as 0104 (RAID bus controller) rather than
  # 0107 while still using the SAS transport, and VMware's virtual LSI SAS controller -
  # the exact case that motivated this fix - commonly reports as 0100 (plain SCSI). So
  # match all three classes (0100/0104/0107), same set as disks.sh's _has_hba_driver().
  if lspci -n 2>/dev/null | grep -qE ' (0100|0104|0107):'; then
    [ -f "/addons/synoinfo.conf" ] && UCONF="/addons/synoinfo.conf" || UCONF="/usr/arc/addons/synoinfo.conf"
    if [ -f "${UCONF}" ]; then
      USER_SAS="$(/bin/get_key_value "${UCONF}" "supportsas")"
      if [ -n "${USER_SAS}" ]; then
        for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do
          /bin/set_key_value "${F}" "supportsas" "${USER_SAS}"
        done
        echo "disks addon: apply user supportsas=${USER_SAS}"
      fi
    fi
  fi

  /usr/bin/disks.sh --create

elif [ "${1}" = "late" ]; then
  echo "Installing addon disks - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/bin/disks.sh /tmpRoot/usr/bin/disks.sh
  {
    echo '# Author: "SynoCommunity"'
    echo ''
    echo '# general disks dtb rules'
    echo 'ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{DEVNAME}=="/dev/nvme*|/dev/sas*|/dev/sd*|/dev/sata*", PROGRAM=="/usr/bin/disks.sh --update %E{DEVNAME}"'
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
  KVLIST="${KVLIST} maxdisks supportnvme support_m2_pool supportsas" # support_ssd_cache support_write_cache"

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
