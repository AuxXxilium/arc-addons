#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

NVMECACHE_MODELS="DS918+ RS1619xs+ DS419+ DS1019+ DS719+ DS1621xs+"
MODEL="$(grep -o 'syno_hw_version=[^ ]*' /proc/cmdline 2>/dev/null | cut -d'=' -f2)"

if [ "${1}" = "patches" ]; then
  echo "Installing addon disks - ${1}"

  /usr/bin/disks.sh --create

  # NVMe cache PCI path discovery (for models that need libsynonvme patching).
  if echo "${NVMECACHE_MODELS}" | grep -wq "${MODEL}"; then
    BOOTDISK_PART3_PATH="$(/sbin/blkid -L ARC3 2>/dev/null)"
    if [ -n "${BOOTDISK_PART3_PATH}" ]; then
      BOOTDISK_PART3_MAJORMINOR="$(stat -c '%t:%T' "${BOOTDISK_PART3_PATH}" | awk -F: '{printf "%d:%d", strtonum("0x" $1), strtonum("0x" $2)}')"
      BOOTDISK_PART3="$(awk -F= '/DEVNAME/ {print $2}' "/sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent" 2>/dev/null)"
    fi
    if [ -n "${BOOTDISK_PART3}" ]; then
      BOOTDISK="$(basename "$(dirname /sys/block/*/${BOOTDISK_PART3} 2>/dev/null)" 2>/dev/null)"
      BOOTDISK_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "/sys/block/${BOOTDISK}/uevent" 2>/dev/null)"
    fi
    rm -f /etc/nvmePorts
    for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
      [ ! -e "${F}" ] && continue
      PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
      [ -z "${PHYSDEVPATH}" ] && continue
      [ "${BOOTDISK_PHYSDEVPATH}" = "${PHYSDEVPATH}" ] && continue
      PCIEPATH="$(echo "${PHYSDEVPATH}" | awk -F'/' '{if (NF == 4) print $NF; else if (NF > 4) print $(NF-1)}')"
      grep -q "${PCIEPATH}" /etc/nvmePorts 2>/dev/null && continue
      echo "${PCIEPATH}" >>/etc/nvmePorts
    done
    [ -f /etc/nvmePorts ] && echo "disks addon: nvmePorts=$(cat /etc/nvmePorts | tr '\n' ' ')"
  fi

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

  # Patch libsynonvme to redirect hardcoded NVMe cache PCI paths to actual hardware.
  if echo "${NVMECACHE_MODELS}" | grep -wq "${MODEL}"; then
    if [ -f /etc/nvmePorts ]; then
      SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
      if [ -f "${SO_FILE}" ]; then
        [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
        cp -pf "${SO_FILE}.bak" "${SO_FILE}"
        sed -i "s/0000:00:13.1/0000:99:99.0/; s/0000:00:03.2/0000:99:99.0/; s/0000:00:14.1/0000:99:99.0/; s/0000:00:01.1/0000:99:99.0/" "${SO_FILE}"
        sed -i "s/0000:00:13.2/0000:99:99.1/; s/0000:00:03.3/0000:99:99.1/; s/0000:00:99.9/0000:99:99.1/; s/0000:00:01.0/0000:99:99.1/" "${SO_FILE}"
        idx=0
        while IFS= read -r N; do
          [ -z "${N}" ] && continue
          if [ ${idx} -eq 0 ]; then
            sed -i "s/0000:99:99.0/${N}/g" "${SO_FILE}"
          elif [ ${idx} -eq 1 ]; then
            sed -i "s/0000:99:99.1/${N}/g" "${SO_FILE}"
          else
            break
          fi
          echo "disks addon: nvmecache slot${idx}=${N}"
          idx=$((idx + 1))
        done </etc/nvmePorts
      fi
    else
      echo "disks addon: nvmePorts not found, skipping libsynonvme patch"
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

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"
fi