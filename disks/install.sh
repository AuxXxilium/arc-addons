#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Get values in synoinfo.conf K=V file
# Args: $1 rd|hd, $2 key
_get_conf_kv() {
  local ROOT FILE
  [ "$1" = "rd" ] && ROOT="" || ROOT="/tmpRoot"
  FILE="${ROOT}/etc.defaults/synoinfo.conf"
  grep "^${2}=" "${FILE}" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//' 2>/dev/null
}

# Replace/add values in synoinfo.conf K=V file
# Args: $1 rd|hd, $2 key, $3 val
_set_conf_kv() {
  local ROOT FILE
  [ "$1" = "rd" ] && ROOT="" || ROOT="/tmpRoot"
  for SD in etc etc.defaults; do
    FILE="${ROOT}/${SD}/synoinfo.conf"
    if [ -z "${3}" ]; then
      sed -i "/^${2}=/d" "${FILE}" 2>/dev/null
      continue
    fi
    if grep -q "^${2}=" "${FILE}"; then
      sed -i "s#^${2}=.*#${2}=\"${3}\"#" "${FILE}" 2>/dev/null
      continue
    fi
    echo "${2}=\"${3}\"" >>"${FILE}"
    # continue
  done
}

# Check if the user has customized the key
# Args: $1 rd|hd, $2 key
_check_post_k() {
  local ROOT
  [ "$1" = "rd" ] && ROOT="" || ROOT="/tmpRoot"
  grep -Eq "^_set_conf_kv.*${2}.*" "${ROOT}/sbin/init.post"
}

# Check if the raid has been completed currently
_check_rootraidstatus() {
  [ "$(_get_conf_kv rd supportraid)" = "yes" ] || return 0
  local STATE=$(cat /sys/block/md0/md/array_state 2>/dev/null)
  [ $? -ne 0 ] && return 1
  case ${STATE} in
  "clear" | "inactive" | "suspended" | "readonly" | "read-auto") return 1 ;;
  esac
  return 0
}

# Convert disk name to integer
# Args: $1 disk name
_atoi() {
  local DISKNAME=${1} NUM=0 IDX=0 N BIT
  while [ ${IDX} -lt ${#DISKNAME} ]; do
    N=$(($(printf '%d' "'${DISKNAME:${IDX}:1}") - $(printf '%d' "'a") + 1))
    BIT=$((${#DISKNAME} - 1 - ${IDX}))
    NUM=$((NUM + (BIT == 0 ? N : 26 ** BIT * N)))
    IDX=$((IDX + 1))
  done
  echo $((NUM - 1))
}

# Generate linux kernel version code
# Args: $1 version string
_kernelVersionCode() {
  [ $# -eq 1 ] || return

  local _version_string _major_version _minor_version _revision
  _version_string="$(echo "$1" | /usr/bin/cut -d'_' -f1)."
  _major_version=$(echo "${_version_string}" | /usr/bin/cut -d'.' -f1)
  _minor_version=$(echo "${_version_string}" | /usr/bin/cut -d'.' -f2)
  _revision=$(echo "${_version_string}" | /usr/bin/cut -d'.' -f3)

  /bin/echo $((${_major_version:-0} * 65536 + ${_minor_version:-0} * 256 + ${_revision:-0}))
}

# Get current linux kernel version without extra version
# format: VERSION.PATCHLEVEL.SUBLEVEL
# ex. "2.6.32"
_kernelVersion() {
  local _release
  _release=$(/bin/uname -r)
  /bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3
}

# synoboot
checkSynoboot() {
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    [ -z "${BOOTDISK}" ] && return
    if [ ! -b /dev/synoboot ] && [ -d /sys/block/${BOOTDISK} ]; then
      mknod /dev/synoboot b $(cat /sys/block/${BOOTDISK}/dev | sed 's/:/ /') >/dev/null 2>&1
      rm -vf /dev/${BOOTDISK}
    fi
    for i in 1 2 3 p1 p2 p3; do
      if [ ! -b /dev/synoboot${i/p/} ] && [ -d /sys/block/${BOOTDISK}/${BOOTDISK}${i} ]; then
        mknod /dev/synoboot${i/p/} b $(cat /sys/block/${BOOTDISK}/${BOOTDISK}${i}/dev | sed 's/:/ /') >/dev/null 2>&1
        rm -vf /dev/${BOOTDISK}${i}
      fi
    done
  fi
}

# USB ports
getUsbPorts() {
  for I in $(ls -d /sys/bus/usb/devices/usb* 2>/dev/null); do
    local DCLASS SPEED RBUS RCHILDS HAVE_CHILD=0
    DCLASS=$(cat ${I}/bDeviceClass)
    [ "${DCLASS}" != "09" ] && continue
    SPEED=$(cat ${I}/speed)
    [ ${SPEED} -lt 480 ] && continue
    RBUS=$(cat ${I}/busnum)
    RCHILDS=$(cat ${I}/maxchild)
    for C in $(seq 1 ${RCHILDS}); do
      local SUB="${RBUS}-${C}"
      if [ -d "${I}/${SUB}" ]; then
        DCLASS=$(cat ${I}/${SUB}/bDeviceClass)
        [ ! "${DCLASS}" = "09" ] && continue
        SPEED=$(cat ${I}/${SUB}/speed)
        [ ${SPEED} -lt 480 ] && continue
        local CHILDS=$(cat ${I}/${SUB}/maxchild)
        HAVE_CHILD=1
        for N in $(seq 1 ${CHILDS}); do
          echo -n "${RBUS}-${C}.${N} "
        done
      fi
    done
    [ ${HAVE_CHILD} -eq 0 ] && for N in $(seq 1 ${RCHILDS}); do echo -n "${RBUS}-${N} "; done
  done
  echo
}

#
dtModel() {
  DEST="/addons/model.dts"
  UNIQUE=$(_get_conf_kv rd unique)
  if [ ! -f "${DEST}" ]; then # Users can put their own dts.
    {
      echo "/dts-v1/;"
      echo "/ {"
      echo "    compatible = \"Synology\";"
      echo "    model = \"${UNIQUE}\";"
      echo "    version = <0x01>;"
      echo "    power_limit = \"\";"
    } >"${DEST}"
    # SATA ports
    if [ "${1}" = "true" ]; then
      I=1
      for P in $(lspci -d ::106 2>/dev/null | cut -d' ' -f1); do
        HOSTNUM=$(ls -l /sys/class/scsi_host 2>/dev/null | grep ${P} | wc -l)
        PCIHEAD="$(ls -l /sys/class/scsi_host 2>/dev/null | grep ${P} | head -1)"
        PCIPATH=""
        if [ "$(_kernelVersionCode "$(_kernelVersion)")" -ge "$(_kernelVersionCode "5.10")" ]; then
          PCIPATH="$(echo "${PCIHEAD}" | grep -Eo 'pci[0-9]{4}:[0-9]{2}' | sed 's/pci//')" # 5.10+ kernel
        else
          PCIPATH="$(echo "${PCIHEAD}" | grep -Eo 'pci[0-9]{4}:[0-9]{2}' | sed 's/pci//' | cut -d':' -f2)" # 5.10- kernel
        fi
        PCISUBS=""
        for Q in $(echo "${PCIHEAD}" | grep -Eo ":..\.."); do PCISUBS="${PCISUBS},${Q//:/}"; done
        [ -z "${PCISUBS}" ] && continue
        PCIPATH="${PCIPATH}:${PCISUBS:1}"

        IDX=""
        if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && echo "${BOOTDISK_PHYSDEVPATH}" | grep -q "${P}"; then
          IDX=$(ls -l /sys/class/scsi_host 2>/dev/null | grep ${P} | sort -V | grep -n "${BOOTDISK_PHYSDEVPATH%%target*}" | head -1 | cut -d: -f1)
          if [ -n "${IDX}" ] && echo "${IDX}" | grep -Eq '^[0-9]+$'; then if [ ${IDX} -gt 0 ]; then IDX=$((${IDX} - 1)); else IDX="0"; fi; else IDX=""; fi
          echo "bootloader: PCIPATH:${PCIPATH}; IDX:${IDX}"
        fi

        for J in $(seq 0 $((${HOSTNUM} - 1))); do
          [ "${J}" = "${IDX}" ] && continue
          {
            echo "    internal_slot@${I} {"
            echo "        protocol_type = \"sata\";"
            echo "        ahci {"
            echo "            pcie_root = \"${PCIPATH}\";"
            echo "            ata_port = <0x$(printf '%02X' ${J})>;"
            echo "        };"
            echo "    };"
          } >>"${DEST}"
          I=$((${I} + 1))
        done
      done
      for P in $(lspci -d ::107 2>/dev/null | cut -d' ' -f1) $(lspci -d ::104 2>/dev/null | cut -d' ' -f1) $(lspci -d ::100 2>/dev/null | cut -d' ' -f1); do
        J=1
        while true; do
          [ ! -d /sys/block/sata${J} ] && break
          if cat /sys/block/sata${J}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | grep -q "${P}"; then
            if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "$(cat /sys/block/sata${J}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
              echo "bootloader: /sys/block/sata${J}"
            else
              PCIEPATH="$(grep 'pciepath' /sys/block/sata${J}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
              ATAPORT="$(grep 'ata_port_no' /sys/block/sata${J}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
              if [ -n "${PCIEPATH}" ] && [ -n "${ATAPORT}" ]; then
                {
                  echo "    internal_slot@${I} {"
                  echo "        protocol_type = \"sata\";"
                  echo "        ahci {"
                  echo "            pcie_root = \"${PCIEPATH}\";"
                  echo "            ata_port = <0x$(printf '%02X' ${ATAPORT})>;"
                  echo "        };"
                  echo "    };"
                } >>"${DEST}"
                I=$((${I} + 1))
              fi
            fi
          fi
          J=$((${J} + 1))
        done
      done
    else
      I=1
      J=1
      while true; do
        [ ! -d /sys/block/sata${J} ] && break
        if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "$(cat /sys/block/sata${J}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
          echo "bootloader: /sys/block/sata${J}"
        else
          PCIEPATH="$(grep 'pciepath' /sys/block/sata${J}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
          ATAPORT="$(grep 'ata_port_no' /sys/block/sata${J}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
          if [ -n "${PCIEPATH}" ] && [ -n "${ATAPORT}" ]; then
            {
              echo "    internal_slot@${I} {"
              echo "        protocol_type = \"sata\";"
              echo "        ahci {"
              echo "            pcie_root = \"${PCIEPATH}\";"
              echo "            ata_port = <0x$(printf '%02X' ${ATAPORT})>;"
              echo "        };"
              echo "    };"
            } >>"${DEST}"
            I=$((${I} + 1))
          fi
        fi
        J=$((${J} + 1))
      done
    fi
    MAXDISKS=$((${I} - 1))
    if _check_post_k "rd" "maxdisks"; then
      MAXDISKS=$(($(_get_conf_kv rd maxdisks)))
      echo "get maxdisks=${MAXDISKS}"
    else
      [ ${MAXDISKS} -lt 26 ] && MAXDISKS=26
    fi
    # Raidtool will read maxdisks, but when maxdisks is greater than 27, formatting error will occur 8%.
    if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
      MAXDISKS=26
      echo "set maxdisks=26 [${MAXDISKS}]"
    fi
    _set_conf_kv rd "maxdisks" "${MAXDISKS}"
    echo "maxdisks=${MAXDISKS}"

    # NVME ports
    COUNT=0
    POWER_LIMIT=""
    for P in $(ls -d /sys/block/nvme* 2>/dev/null); do
      if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
        echo "bootloader: ${P}"
        continue
      fi
      PCIEPATH="$(grep 'pciepath' ${P}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
      if [ -n "${PCIEPATH}" ]; then
        grep -q "pcie_root = \"${PCIEPATH}\";" ${DEST} && continue # An nvme controller only recognizes one disk
        [ $((${#POWER_LIMIT} - 1 + 2)) -gt 30 ] && break           # POWER_LIMIT string length limit 30 characters
        COUNT=$((${COUNT} + 1))
        {
          echo "    nvme_slot@${COUNT} {"
          echo "        pcie_root = \"${PCIEPATH}\";"
          echo "        port_type = \"ssdcache\";"
          echo "    };"
        } >>"${DEST}"
        POWER_LIMIT="${POWER_LIMIT},0"
      fi
    done
    [ -n "${POWER_LIMIT:1}" ] && sed -i "s/power_limit = .*/power_limit = \"${POWER_LIMIT:1}\";/" ${DEST} || sed -i '/power_limit/d' ${DEST}
    if [ ${COUNT} -gt 0 ]; then
      _set_conf_kv rd "supportnvme" "yes"
      _set_conf_kv rd "support_m2_pool" "yes"
    fi

    # USB ports
    COUNT=0
    for I in $(getUsbPorts); do
      COUNT=$((${COUNT} + 1))
      {
        echo "    usb_slot@${COUNT} {"
        echo "      usb2 {"
        echo "        usb_port = \"${I}\";"
        echo "      };"
        echo "      usb3 {"
        echo "        usb_port = \"${I}\";"
        echo "      };"
        echo "    };"
      } >>"${DEST}"
    done
    echo "};" >>"${DEST}"
  else
    MAXDISKS=$(grep -c "internal_slot@" "${DEST}" 2>/dev/null)
    if _check_post_k "rd" "maxdisks"; then
      MAXDISKS=$(($(_get_conf_kv rd maxdisks)))
      echo "get maxdisks=${MAXDISKS}"
    else
      [ ${MAXDISKS:-0} -lt 26 ] && MAXDISKS=26
    fi
    # Raidtool will read maxdisks, but when maxdisks is greater than 27, formatting error will occur 8%.
    if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
      MAXDISKS=26
      echo "set maxdisks=26 [${MAXDISKS}]"
    fi
    _set_conf_kv rd "maxdisks" "${MAXDISKS}"
    echo "maxdisks=${MAXDISKS}"

    if grep -q "nvme_slot@" "${DEST}" 2>/dev/null; then
      _set_conf_kv rd "supportnvme" "yes"
      _set_conf_kv rd "support_m2_pool" "yes"
    fi
  fi
  dtc -I dts -O dtb "${DEST}" >/etc/model.dtb
  cp -vpf /etc/model.dtb /run/model.dtb
  /usr/syno/bin/syno_slot_mapping
}

#
nondtModel() {
  MAXDISKS=0
  USBPORTCFG=0
  ESATAPORTCFG=0
  INTERNALPORTCFG=0

  hasUSB=false
  USBMINIDX=99
  USBMAXIDX=00
  for I in $(ls -d /sys/block/sd* 2>/dev/null); do
    IDX=$(_atoi ${I/\/sys\/block\/sd/})
    [ $((${IDX} + 1)) -ge ${MAXDISKS} ] && MAXDISKS=$((${IDX} + 1))
    ISUSB="$(cat ${I}/uevent 2>/dev/null | grep PHYSDEVPATH | grep usb)"
    if [ -n "${ISUSB}" ]; then
      if [ "${hasUSB}" = "false" ]; then
        [ ${IDX} -lt ${USBMINIDX} ] && USBMINIDX=${IDX}
        [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
        hasUSB=true
      else
        [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
      fi
    fi
  done
  # Define 6 is the minimum number of USB disks
  if [ "${hasUSB}" = "false" ]; then
    USBMINIDX=${MAXDISKS}
    USBMAXIDX=$((${USBMINIDX} + 6 - 1))
  else
    [ $((${USBMAXIDX} - ${USBMINIDX})) -lt $((6 - 1)) ] && USBMAXIDX=$((${USBMINIDX} + 6 - 1))
  fi
  [ $((${USBMAXIDX} + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((${USBMAXIDX} + 1))

  if _check_post_k "rd" "maxdisks"; then
    MAXDISKS=$(($(_get_conf_kv rd maxdisks)))
    printf "get maxdisks=%d\n" "${MAXDISKS}"
  else
    printf "cal maxdisks=%d\n" "${MAXDISKS}"
  fi

  if grep -wq "usbinternal" /proc/cmdline 2>/dev/null; then
    USBPORTCFG=0
    _set_conf_kv rd "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  elif _check_post_k "rd" "usbportcfg"; then
    USBPORTCFG=$(($(_get_conf_kv rd usbportcfg)))
    printf 'get usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  else
    USBPORTCFG=$(($((2 ** $((${USBMAXIDX} + 1)) - 1)) ^ $((2 ** ${USBMINIDX} - 1))))
    _set_conf_kv rd "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  fi
  if _check_post_k "rd" "esataportcfg"; then
    ESATAPORTCFG=$(($(_get_conf_kv rd esataportcfg)))
    printf 'get esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
  else
    _set_conf_kv rd "esataportcfg" "$(printf "0x%.2x" ${ESATAPORTCFG})"
    printf 'set esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
  fi
  if _check_post_k "rd" "internalportcfg"; then
    INTERNALPORTCFG=$(($(_get_conf_kv rd internalportcfg)))
    printf 'get internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  else
    INTERNALPORTCFG=$(($((2 ** ${MAXDISKS} - 1)) ^ ${USBPORTCFG} ^ ${ESATAPORTCFG}))
    _set_conf_kv rd "internalportcfg" "$(printf "0x%.2x" ${INTERNALPORTCFG})"
    printf 'set internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  fi

  # Raidtool will read maxdisks, but when maxdisks is greater than 27, formatting error will occur 8%.
  if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
    MAXDISKS=26
    printf "set maxdisks=26 [%d]\n" "${MAXDISKS}"
  fi
  _set_conf_kv rd "maxdisks" "${MAXDISKS}"
  printf "set maxdisks=%d\n" "${MAXDISKS}"

  # NVME
  COUNT=1
  echo "[pci]" >/etc/extensionPorts
  for P in $(ls -d /sys/block/nvme* 2>/dev/null); do
    if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
      echo "bootloader: ${P}"
      continue
    fi
    PCIEPATH="$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2 | awk -F'/' '{if (NF == 4) print $NF; else if (NF > 4) print $(NF-1)}')"
    if [ -n "${PCIEPATH}" ]; then
      grep -q "=\"${PCIEPATH}\"" /etc/extensionPorts && continue # An nvme controller only recognizes one disk
      echo "pci${COUNT}=\"${PCIEPATH}\"" >>/etc/extensionPorts
      COUNT=$((${COUNT} + 1))

      _set_conf_kv rd "supportnvme" "yes"
      _set_conf_kv rd "support_m2_pool" "yes"
    fi
  done
}

# execute main
case "${1}" in
  "patches")
    echo "Installing addon disks - ${1}"

    BOOTDISK_PART3_PATH="$(blkid -L ARC3 2>/dev/null)"
    if [ -n "${BOOTDISK_PART3_PATH}" ]; then
      BOOTDISK_PART3_MAJORMINOR="$((0x$(stat -c '%t' "${BOOTDISK_PART3_PATH}"))):$((0x$(stat -c '%T' "${BOOTDISK_PART3_PATH}")))"
      BOOTDISK_PART3="$(grep 'DEVNAME' /sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent 2>/dev/null | cut -d'=' -f2)"
      BOOTDISK="$(ls -d /sys/block/*/${BOOTDISK_PART3} 2>/dev/null | cut -d'/' -f4)"
      BOOTDISK_PHYSDEVPATH="$(grep 'PHYSDEVPATH' /sys/block/${BOOTDISK}/uevent 2>/dev/null | cut -d'=' -f2)"
    fi

    echo "BOOTDISK=${BOOTDISK}"
    echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"

    checkSynoboot

    if [ "$(_get_conf_kv rd supportportmappingv2)" = "yes" ]; then
      dtModel "${2}"
    else
      nondtModel "${2}"
    fi
    ;;
  "late")
    echo "Installing addon disks - ${1}"
    if [ "$(_get_conf_kv rd supportportmappingv2)" = "yes" ]; then
      echo "Copying /etc.defaults/model.dtb"
      cp -vpf /usr/bin/dtc /tmpRoot/usr/bin/dtc
      cp -vpf /etc/model.dtb /tmpRoot/etc/model.dtb
      cp -vpf /etc/model.dtb /tmpRoot/etc.defaults/model.dtb
    else
      echo "Adjust maxdisks and internalportcfg automatically"
      USBPORTCFG=$(_get_conf_kv rd usbportcfg)
      ESATAPORTCFG=$(_get_conf_kv rd esataportcfg)
      INTERNALPORTCFG=$(_get_conf_kv rd internalportcfg)
      echo "usbportcfg=${USBPORTCFG}"
      echo "esataportcfg=${ESATAPORTCFG}"
      echo "internalportcfg=${INTERNALPORTCFG}"
      _set_conf_kv hd "usbportcfg" "${USBPORTCFG}"
      _set_conf_kv hd "esataportcfg" "${ESATAPORTCFG}"
      _set_conf_kv hd "internalportcfg" "${INTERNALPORTCFG}"
      cp -vpf /etc/extensionPorts /tmpRoot/etc/extensionPorts
      cp -vpf /etc/extensionPorts /tmpRoot/etc.defaults/extensionPorts
    fi

    MAXDISKS=$(_get_conf_kv rd maxdisks)
    echo "maxdisks=${MAXDISKS}"
    _set_conf_kv hd "maxdisks" "${MAXDISKS}"

    SUPPORTNVME=$(_get_conf_kv rd supportnvme)
    SUPPORT_M2_POOL=$(_get_conf_kv rd support_m2_pool)
    _set_conf_kv hd "supportnvme" "${SUPPORTNVME}"
    _set_conf_kv hd "support_m2_pool" "${SUPPORT_M2_POOL}"
    ;;
esac