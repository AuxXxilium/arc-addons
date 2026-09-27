#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# libsynodiskmap's M.2 card table ends in an FX2422N entry that matches any
# ASMedia ASM2824 switch - vendor/device only, no subsystem, and a config check
# of offset/mask/shift/value all zero, so it is always true. Every NVMe behind a
# generic ASM2824 card is therefore taken for an FX2422N, which only FS6600N
# enables in adapter_cards.conf: elsewhere scemd leaves the drives out of its
# enum list (no cache/M.2 slot, hdddb never sees them). Synology's own cards
# carry subsystem 7053:xxxx and match their entries before this one.
#
# Setting the entry's mask to ffffffff makes the check compare the config
# dword at offset 0 (vendor|device) against 0, which never matches, so those
# drives fall through to ON-BOARD and take their nvme_slot from model.dtb.
# Matched by content, not offset: model, sata/nvme/eth depth, two build-
# specific pointers, no subsystem, the check, then RX1224rp's entry header.
# $1: on | off
_fx2422n_patch() {
  _F="/tmpRoot/usr/lib/libsynodiskmap.so.1"
  [ -f "${_F}" ] || return 0
  _PRE='05000000ffffffff05000000ffffffff.\{32\}0\{32\}00000000'
  _POST='0\{16\}0800000007000000'
  if [ "${1}" = "on" ]; then _FROM=00000000; _TO=ffffffff; else _FROM=ffffffff; _TO=00000000; fi
  _HEX="$(xxd -c "$(xxd -p "${_F}" 2>/dev/null | wc -c)" -p "${_F}" 2>/dev/null)"
  if [ "$(echo "${_HEX}" | grep -o "${_PRE}${_FROM}${_POST}" | wc -l)" -ne 1 ]; then
    if echo "${_HEX}" | grep -q "${_PRE}${_TO}${_POST}"; then
      echo "disks addon: FX2422N match for generic ASM2824 cards already ${1}"
    else
      echo "disks addon: FX2422N entry not found, libsynodiskmap left as is"
    fi
    return 0
  fi
  echo "${_HEX}" | sed "s/\(${_PRE}\)${_FROM}\(${_POST}\)/\1${_TO}\2/" | xxd -r -p >"${_F}.new" 2>/dev/null
  if [ "$(wc -c <"${_F}.new" 2>/dev/null)" = "$(wc -c <"${_F}" 2>/dev/null)" ]; then
    # In place, not mv, to keep the inode and mode - as nvmevolume does.
    cat "${_F}.new" >"${_F}"
    echo "disks addon: FX2422N match for generic ASM2824 cards ${1}"
  else
    echo "disks addon: FX2422N patch produced unexpected output, libsynodiskmap left as is"
  fi
  rm -f "${_F}.new"
}

if [ "${1}" = "patches" ]; then
  echo "Installing addon disks - ${1}"

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
    # The persisted copy tracks the loader: /addons/model.dts is re-injected on
    # every boot that has an upload configured, so its absence means the user
    # removed it and the stale copy has to go with it.
    #
    # The old code got the delete right but not the keep: it wrote
    # /etc/user_model.dts and nothing ever read it back, so dtModel()
    # auto-generated over the upload as soon as the ramdisk was out of the
    # picture. disks.sh now treats it as a real source, which is what makes
    # this branch meaningful rather than write-only.
    if [ -f "/addons/model.dts" ]; then
      cp -vpf /addons/model.dts /tmpRoot/etc/user_model.dts
      rm -vf /tmpRoot/etc/user_model.dts.bad
    else
      rm -vf /tmpRoot/etc/user_model.dts /tmpRoot/etc/user_model.dts.bad
    fi
  else
    KVLIST="${KVLIST} usbportcfg esataportcfg eunitseq internalportcfg"

    cp -vpf /etc/extensionPorts /tmpRoot/etc/extensionPorts
    cp -vpf /etc/extensionPorts /tmpRoot/etc.defaults/extensionPorts
  fi
  KVLIST="${KVLIST} maxdisks supportnvme support_m2_pool" # support_ssd_cache support_write_cache

  for K in ${KVLIST}; do
    V="$(/bin/get_key_value "/etc.defaults/synoinfo.conf" "${K}")"
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do
      /bin/set_key_value "${F}" "${K}" "${V}"
    done
    echo "disks addon: ${K}=${V}"
  done

  # FX2422N is real only on FS6600N, the one model adapter_cards.conf enables it for.
  case "$(cat /proc/sys/kernel/syno_hw_version 2>/dev/null)" in
    FS6600N*) ;;
    *) _fx2422n_patch on ;;
  esac

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon disks - ${1}"

  rm -rf "/tmpRoot/usr/bin/disks.sh"
  rm -rf "/tmpRoot/usr/lib/udev/rules.d/04-system-disk-dtb.rules"
  rm -rf "/tmpRoot/usr/bin/dtc"
  # Reversed in place rather than restored from a backup, which a DSM update
  # in between would have made stale.
  _fx2422n_patch off
fi
