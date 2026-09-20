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

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon disks - ${1}"

  rm -rf "/tmpRoot/usr/bin/disks.sh"
  rm -rf "/tmpRoot/usr/lib/udev/rules.d/04-system-disk-dtb.rules"
  rm -rf "/tmpRoot/usr/bin/dtc"
fi
