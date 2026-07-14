#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

ROOT_PATH=""
GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

_log() {
  echo "disks: $*"
  /bin/logger -p "error" -t "disks" "$@"
}

__get_conf_kv() {
  "${GKV}" "${ROOT_PATH}/etc.defaults/synoinfo.conf" "${1}" 2>/dev/null
}

__set_conf_kv() {
  for F in "${ROOT_PATH}/etc/synoinfo.conf" "${ROOT_PATH}/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "${1}" "${2}"; done
}

_check_user_conf() {
  [ -f "/addons/synoinfo.conf" ] && UCONF="/addons/synoinfo.conf" || UCONF="/usr/arc/addons/synoinfo.conf"
  grep -Eq "^${1}=" "${UCONF}" 2>/dev/null
}

_has_hba_driver() {
  lspci -n 2>/dev/null | grep -qE ' (0100|0104|0107):'
}

_count_disks() {
  C=0
  for _F in ${1}; do [ -e "${_F}" ] && C=$((C + 1)); done
  echo "${C}"
}

_wait_hba_disks_stable() {
  [ "${_HBA_WAIT_DONE:-0}" = "1" ] && return 0
  _HBA_WAIT_DONE=1

  if ! _has_hba_driver; then
    _log "no HBA driver found, skipping disk stabilisation wait"
    return 0
  fi

  _whba_globs="${*:-/sys/block/sd*}"

  _whba_count() {
    _C=0
    for _G in ${_whba_globs}; do _C=$((_C + $(_count_disks "${_G}"))); done
    echo "${_C}"
  }

  PREV_COUNT="$(_whba_count)"
  STABLE_ROUNDS=0
  I=0
  while [ "${I}" -lt 100 ]; do
    sleep 3
    CUR_COUNT="$(_whba_count)"
    if [ "${CUR_COUNT}" = "${PREV_COUNT}" ]; then
      STABLE_ROUNDS=$((STABLE_ROUNDS + 1))
      [ "${STABLE_ROUNDS}" -ge 5 ] && break
    else
      STABLE_ROUNDS=0
      PREV_COUNT="${CUR_COUNT}"
    fi
    I=$((I + 1))
  done
  if [ "${I}" -ge 100 ]; then
    _log "HBA disk stabilisation wait timed out: [${_whba_globs}] at count ${CUR_COUNT}"
  else
    _log "HBA disks settled: [${_whba_globs}] at count ${CUR_COUNT}"
  fi
}

_atoi() {
  DISKNAME=${1}
  NUM=0
  IDX=0
  while [ ${IDX} -lt ${#DISKNAME} ]; do
    N=$(($(printf '%d' "'$(expr substr "${DISKNAME}" $((IDX + 1)) 1)") - $(printf '%d' "'a") + 1))
    BIT=$(($(expr length "${DISKNAME}") - 1 - IDX))
    # shellcheck disable=SC3019
    NUM=$((NUM + (BIT == 0 ? N : 26 ** BIT * N)))
    IDX=$((IDX + 1))
  done
  echo $((NUM - 1))
}

_check_rootraidstatus() {
  [ "$(__get_conf_kv supportraid)" = "yes" ] || return 1
  [ -f "/sys/block/md0/md/array_state" ] || return 1
  STATE=$(cat "/sys/block/md0/md/array_state" 2>/dev/null)
  case ${STATE} in
    "clear" | "inactive" | "suspended" | "readonly" | "read-auto") return 1 ;;
  esac
  return 0
}

_itol() {
  IFS="${IFS:- }"
  NUM="$(echo $((${1:-"-1"})))"
  IDX=0
  DISKLIST=""
  while [ ${NUM} -gt 0 ]; do
    if [ "$((NUM & 1))" = 1 ]; then
      case $((IDX / 26)) in
        0) dev="$(printf sd\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;;
        *) dev="$(printf sd\\x"$(printf "%x" "$((IDX / 26 - 1 + $(printf '%d' "'a")))")"\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;;
      esac
      DISKLIST="${DISKLIST:+${DISKLIST}${IFS}}${dev}"
    fi
    NUM=$((NUM >> 1))
    IDX=$((IDX + 1))
  done
  echo "${DISKLIST}"
}

checkAlldisk() {
  for F in $(LC_ALL=C printf '%s\n' /sys/block/* | sort -V); do
    [ ! -e "${F}" ] && continue
    N="$(basename "${F}" 2>/dev/null)"

    if [ ! -b "/dev/${N}" ] && [ -d "/sys/block/${N}" ]; then
      MAJOR="$(cat "/sys/block/${N}/dev" | cut -d':' -f1)"
      MINOR="$(cat "/sys/block/${N}/dev" | cut -d':' -f2)"
      mknod "/dev/${N}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
    fi
    for i in 1 2 3 p1 p2 p3; do
      if [ ! -b "/dev/${N}${i}" ] && [ -d "/sys/block/${N}/${N}${i}" ]; then
        MAJOR="$(cat "/sys/block/${N}/${N}${i}/dev" | cut -d':' -f1)"
        MINOR="$(cat "/sys/block/${N}/${N}${i}/dev" | cut -d':' -f2)"
        mknod "/dev/${N}${i}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
      fi
    done
  done

}

checkSynoboot() {
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    [ -z "${BOOTDISK}" ] && return
    if [ ! -b "/dev/synoboot" ] && [ -d "/sys/block/${BOOTDISK}" ]; then
      MAJOR="$(cat "/sys/block/${BOOTDISK}/dev" | cut -d':' -f1)"
      MINOR="$(cat "/sys/block/${BOOTDISK}/dev" | cut -d':' -f2)"
      mknod "/dev/synoboot" b ${MAJOR} ${MINOR} >/dev/null 2>&1
      rm -vf "/dev/${BOOTDISK}"
    fi
    for i in 1 2 3 p1 p2 p3; do
      n=$(echo "${i}" | sed 's/p//')
      if [ ! -b "/dev/synoboot${n}" ] && [ -d "/sys/block/${BOOTDISK}/${BOOTDISK}${i}" ]; then
        MAJOR="$(cat "/sys/block/${BOOTDISK}/${BOOTDISK}${i}/dev" | cut -d':' -f1)"
        MINOR="$(cat "/sys/block/${BOOTDISK}/${BOOTDISK}${i}/dev" | cut -d':' -f2)"
        mknod "/dev/synoboot${n}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
        rm -vf "/dev/${BOOTDISK}${i}"
      fi
    done
  fi
}

getUsbPorts() {
  for F in $(LC_ALL=C printf '%s\n' /sys/bus/usb/devices/usb* | sort -V); do
    [ ! -e "${F}" ] && continue
    RCHILDS=0
    RBUS=0
    HAVE_CHILD=0
    [ ! "$(cat "${F}/bDeviceClass" 2>/dev/null)" = "09" ] && continue
    [ "$(cat "${F}/speed" 2>/dev/null)" -lt 480 ] && continue
    RCHILDS=$(cat ${F}/maxchild 2>/dev/null)
    RBUS=$(cat "${F}/busnum" 2>/dev/null)
    for C in $(seq 1 ${RCHILDS:-0}); do
      if [ -d "${F}/${RBUS:-0}-${C}" ]; then
        [ ! "$(cat "${F}/${RBUS:-0}-${C}/bDeviceClass" 2>/dev/null)" = "09" ] && continue
        [ "$(cat "${F}/${RBUS:-0}-${C}/speed" 2>/dev/null)" -lt 480 ] && continue
        HAVE_CHILD=1
        CHILDS=$(cat "${F}/${RBUS:-0}-${C}/maxchild" 2>/dev/null)
        for N in $(seq 1 ${CHILDS:-0}); do printf "${RBUS:-0}-${C}.${N} "; done
      fi
    done
    [ ${HAVE_CHILD} -eq 0 ] && for N in $(seq 1 ${RCHILDS:-0}); do printf "${RBUS:-0}-${N} "; done
  done
  echo
}

dtModel() {
  _log dtModel

  UNIQUE=$(__get_conf_kv unique)

  _wait_hba_disks_stable "/sys/block/sata*"

  DEST="/etc/model.dts"
  [ -f "/addons/model.dts" ] && cp -vpf "/addons/model.dts" "${DEST}"
  if [ ! -f "${DEST}" ]; then
    mkdir -p "$(dirname "${DEST}" 2>/dev/null)"
    {
      echo "/dts-v1/;"
      echo "/ {"
      echo '    compatible = "Synology";'
      echo '    model = "";'
      echo "    version = <0x01>;"
      echo "    #address-cells = <1>;"
      echo "    #size-cells = <0>;"
      echo '    power_limit = "";'
    } >"${DEST}"

    COUNT=0

    for _F in $(LC_ALL=C printf '%s\n' /sys/block/sata* | sort -V); do
      [ -e "${_F}" ] || continue
      _N="$(basename "${_F}")"
      [ -n "${BOOTDISK}" ] && [ "${_N}" = "${BOOTDISK}" ] && { _log "bootloader: ${_F}"; continue; }
      _PP="$(awk -F= '/PHYSDEVPATH/{print $2}' "${_F}/uevent" 2>/dev/null)"
      _PC="$(grep 'pciepath' "${_F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      _AT="$(grep 'ata_port_no' "${_F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      _DR="$(grep 'driver' "${_F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      if [ -z "${_PC}" ] && [ -n "${_PP}" ]; then
        _PC="$(printf '%s' "${_PP}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
      fi
      if [ -n "${_PC}" ] && [ -z "${_DR}" ] && [ -L "/sys/bus/pci/devices/${_PC}/driver" ]; then
        _DR="$(basename "$(readlink -f "/sys/bus/pci/devices/${_PC}/driver")")"
      fi
      if [ -n "${_PC}" ]; then
        case "${_PC}" in *:*:*.*) : ;; *) _PC="0000:${_PC}" ;; esac
      else
        _log "unknown: ${_F}"; continue
      fi
      [ -z "${_DR}" ] && { _log "unknown driver: ${_F}"; continue; }
      if [ -z "${_AT}" ] && [ -n "${_PP}" ]; then
        _FB_ATA="$(printf '%s' "${_PP}" | grep -Eo 'ata[0-9]+' | head -1)"
        _FB_CTRL="/sys${_PP%%/ata*}"
        if [ -n "${_FB_ATA}" ] && [ -d "${_FB_CTRL}" ]; then
          _FB_IDX=0
          for _FB_E in $(ls "${_FB_CTRL}" 2>/dev/null | grep '^ata[0-9]' | sort -V); do
            [ "${_FB_E}" = "${_FB_ATA}" ] && { _AT=${_FB_IDX}; break; }
            _FB_IDX=$((_FB_IDX + 1))
          done
        fi
      fi
      if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${_PP}" ] && [ "${_PP}" = "${BOOTDISK_PHYSDEVPATH}" ]; then
        _log "bootloader (alias): ${_F}"; continue
      fi
      if [ "${BOOTDISK_PCIEPATH}" = "${_PC}" ] && [ -n "${BOOTDISK_ATAPORT}" ] && [ "${BOOTDISK_ATAPORT}" = "${_AT}" ]; then
        _log "bootloader (port ${_AT}): ${_F}"; continue
      fi
      if [ -z "${BOOTDISK_ATAPORT}" ] && [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "${_PP}" ]; then
        _log "bootloader (physdevpath): ${_F}"; continue
      fi
      COUNT=$((COUNT + 1))
      {
        echo "    internal_slot@${COUNT} {"
        echo '        protocol_type = "sata";'
        echo "        ${_DR} {"
        echo "            pcie_root = \"${_PC}\";"
        printf "            ata_port = <0x%02X>;\n" "${_AT}"
        echo "            internal_mode;"
        echo "        };"
        echo "    };"
      } >>"${DEST}"
    done

    if echo "${UNIQUE}" | grep -q 'epyc7003ntb'; then
      COUNT=0
      for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
        [ ! -e "${F}" ] && continue
        N="$(basename "${F}")"
        [ -n "${BOOTDISK}" ] && [ "${N}" = "${BOOTDISK}" ] && { _log "bootloader: ${F}"; continue; }
        PCIEPATH="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
        _NVME_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
        if [ -z "${PCIEPATH}" ] && [ -n "${_NVME_PHYSDEVPATH}" ]; then
          PCIEPATH="$(echo "${_NVME_PHYSDEVPATH}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
        fi
        if [ -z "${PCIEPATH}" ]; then
          _log "unknown: ${F}"
          continue
        fi
        if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] || { [ -n "${_NVME_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "${_NVME_PHYSDEVPATH}" ]; }; then
          _log "bootloader: ${F}"
          continue
        fi
        grep -q "pcie_root = \"${PCIEPATH}\";" "${DEST}" && continue
        COUNT=$((COUNT + 1))
        {
          echo "    internal_slot@${COUNT} {"
          echo "        nvme {"
          echo "            pcie_root = \"${PCIEPATH}\";"
          echo "        };"
          echo "    };"
        } >>"${DEST}"
      done
    else
      COUNT=0
      POWER_LIMIT=""
      for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
        [ ! -e "${F}" ] && continue
        N="$(basename "${F}")"
        [ -n "${BOOTDISK}" ] && [ "${N}" = "${BOOTDISK}" ] && { _log "bootloader: ${F}"; continue; }
        PCIEPATH="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
        _NVME_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
        if [ -z "${PCIEPATH}" ] && [ -n "${_NVME_PHYSDEVPATH}" ]; then
          PCIEPATH="$(echo "${_NVME_PHYSDEVPATH}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
        fi
        if [ -z "${PCIEPATH}" ]; then
          _log "unknown: ${F}"
          continue
        fi
        if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] || { [ -n "${_NVME_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "${_NVME_PHYSDEVPATH}" ]; }; then
          _log "bootloader: ${F}"
          continue
        fi
        grep -q "pcie_root = \"${PCIEPATH}\";" "${DEST}" && continue
        [ $((${#POWER_LIMIT} + 2)) -gt 30 ] && break
        POWER_LIMIT="${POWER_LIMIT:+${POWER_LIMIT},}0"
        COUNT=$((COUNT + 1))
        {
          echo "    nvme_slot@${COUNT} {"
          echo "        reg = <${COUNT}>;"
          echo "        pcie_root = \"${PCIEPATH}\";"
          echo '        port_type = "ssdcache";'
          echo "    };"
        } >>"${DEST}"
      done
      [ -n "${POWER_LIMIT}" ] && sed -i "s/power_limit = .*/power_limit = \"${POWER_LIMIT}\";/" "${DEST}" || sed -i '/power_limit/d' "${DEST}"
    fi

    COUNT=0
    for I in $(getUsbPorts); do
      COUNT=$((COUNT + 1))
      {
        echo "    usb_slot@${COUNT} {"
        echo "      reg = <${COUNT}>;"
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
  fi

  _release=$(/bin/uname -r)
  if [ "$(/bin/echo "${_release%%[-+]*}" | /usr/bin/cut -d'.' -f1)" -lt 5 ]; then
    sed -i 's/"0000:\([0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]\.[0-7]\)"/"\1"/g' "${DEST}"
  else
    sed -i 's/"\([0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]\.[0-7]\)"/"0000:\1"/g' "${DEST}"
  fi

  sed -i "0,/version = .*;/s/model = \".*\";/model = \"${UNIQUE}\";/" "${DEST}"

  MAXDISKS=$(grep -c "internal_slot@" "${DEST}" 2>/dev/null)
  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    _log "get maxdisks=${MAXDISKS:-0}"
  else
    [ "${MAXDISKS:-0}" -lt 26 ] && MAXDISKS=26
  fi
  if ! _check_rootraidstatus && [ "${MAXDISKS:-0}" -gt 26 ]; then
    MAXDISKS=26
    _log "set maxdisks=26 [${MAXDISKS:-0}]"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS:-0}"
  _log "maxdisks=${MAXDISKS:-0}"

  if grep -q "nvme_slot@" "${DEST}" 2>/dev/null; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"
    #__set_conf_kv "support_write_cache" "yes"
  fi

  dtc -I dts -O dtb "${DEST}" >/etc/model.dtb
  if [ $? -eq 0 ]; then
    _log "dtc success"
    rm -vf "${DEST}"
    cp -vpf /etc/model.dtb /etc.defaults/model.dtb
    cp -vpf /etc/model.dtb /run/model.dtb
    /usr/syno/bin/syno_slot_mapping
    [ -f "/usr/lib/systemd/system/storagepanel.service" ] && systemctl restart storagepanel.service
    return 0
  else
    _log "dtc error"
    rm -vf "${DEST}"
    cp -vpf /etc.defaults/model.dtb /etc/model.dtb
    return 1
  fi
}

dtUpdate() {
  _log dtUpdate "$*"

  F="$(basename "${1:-}" 2>/dev/null)"
  if [ -z "${F}" ]; then
    _log "No disk found"
    return 1
  fi

  PCIEPATH="$(grep 'pciepath' "/sys/block/${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
  ATAPORT="$(grep 'ata_port_no' "/sys/block/${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
  USBPORT="$(grep 'usb_path' "/sys/block/${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"

  if [ -z "${PCIEPATH}" ] && [ -z "${USBPORT}" ]; then
    _DTUPDATE_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "/sys/block/${F}/uevent" 2>/dev/null)"
    if [ -n "${_DTUPDATE_PHYSDEVPATH}" ]; then
      PCIEPATH="$(echo "${_DTUPDATE_PHYSDEVPATH}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
    fi
    if [ -z "${PCIEPATH}" ] && [ -z "${USBPORT}" ]; then
      _log "unknown: ${F}, triggering full dtModel"
      dtModel
      return $?
    fi
  fi

  TEMP_DTS="/tmp/model.dts"
  dtc -I dtb -O dts /etc/model.dtb >"${TEMP_DTS}"
  if [ -z "${ATAPORT}" ]; then
    sata_slot_find="$(grep "pcie_root = \"${PCIEPATH}\";" "${TEMP_DTS}" 2>/dev/null | head -1)"
  else
    sata_slot_find="$(sed -n "/pcie_root = \"${PCIEPATH}\";/{N;/ata_port = <0x$(printf '%02X' ${ATAPORT})>;/p}" "${TEMP_DTS}" 2>/dev/null)"
  fi
  nvme_slot_find="$(sed -n "/pcie_root = \"${PCIEPATH}\";/{N;/port_type = \"ssdcache\";/p}" "${TEMP_DTS}" 2>/dev/null)"
  usb_slot_find="$(sed -n "/usb3 {/{N;/usb_port = \"${USBPORT}\";/p}" "${TEMP_DTS}" 2>/dev/null)"
  rm -f "${TEMP_DTS}"
  if [ -n "${sata_slot_find}" ] || [ -n "${nvme_slot_find}" ] || [ -n "${usb_slot_find}" ]; then
    _log "${F} is in the model.dts"
    return 0
  fi

  dtModel
}

nondtModel() {
  _log nondtModel

  _wait_hba_disks_stable "/sys/block/sd*"

  MAXDISKS=0
  USBPORTCFG=0
  ESATAPORTCFG=0
  INTERNALPORTCFG=0

  hasUSB=false
  USBMINIDX=99
  USBMAXIDX=0
  MAXNONUSBIDX=-1
  NONUSBMASK=0
  for _ND_N in $(LC_ALL=C printf '%s\n' /sys/block/sd* | sort -V); do
    _ND_N="$(basename "${_ND_N}")"
    F="/sys/block/${_ND_N}"
    [ -e "${F}" ] || continue
    if [ -n "${BOOTDISK}" ] && [ "${_ND_N}" = "${BOOTDISK}" ]; then
      _log "bootloader: ${F}"; continue
    fi
    if [ -n "${BOOTDISK_PHYSDEVPATH}" ]; then
      _N_PP="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
      if [ -n "${_N_PP}" ] && [ "${_N_PP}" = "${BOOTDISK_PHYSDEVPATH}" ]; then
        _log "bootloader (alias): ${F}"; continue
      fi
    fi
    if [ -n "${BOOTDISK_PCIEPATH}" ] && [ -n "${BOOTDISK_ATAPORT}" ]; then
      _N_PCIE="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      _N_ATAPORT="$(grep 'ata_port_no' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      if [ -n "${_N_PCIE}" ] && [ -n "${_N_ATAPORT}" ] && \
         [ "${_N_PCIE}" = "${BOOTDISK_PCIEPATH}" ] && [ "${_N_ATAPORT}" = "${BOOTDISK_ATAPORT}" ]; then
        _log "bootloader (pciepath+ataport): ${F}"; continue
      fi
    fi
    IDX="$(_atoi "${_ND_N#sd}")"
    BIT=$((2 ** IDX))
    [ $((IDX + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((IDX + 1))
    if grep "PHYSDEVPATH" "${F}/uevent" 2>/dev/null | grep -q "usb"; then
      [ ${IDX} -lt ${USBMINIDX} ] && USBMINIDX=${IDX}
      [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
      hasUSB=true
    else
      NONUSBMASK=$((NONUSBMASK | BIT))
      [ ${IDX} -gt ${MAXNONUSBIDX} ] && MAXNONUSBIDX=${IDX}
    fi
  done

  if [ "${hasUSB}" = "true" ]; then
    if [ ${MAXNONUSBIDX} -lt ${USBMINIDX} ]; then
      [ $((USBMAXIDX - USBMINIDX)) -lt $((6 - 1)) ] && USBMAXIDX=$((USBMINIDX + 6 - 1))
    fi
    [ $((USBMAXIDX + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((USBMAXIDX + 1))
  fi

  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    printf "get maxdisks=%d\n" "${MAXDISKS}"
  else
    printf "cal maxdisks=%d\n" "${MAXDISKS}"
  fi

  if grep -wq "usbinternal" /proc/cmdline 2>/dev/null; then
    USBPORTCFG=0
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  elif _check_user_conf "usbportcfg"; then
    USBPORTCFG=$(($(__get_conf_kv usbportcfg)))
    printf 'get usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  elif [ "${hasUSB}" = "true" ]; then
    # shellcheck disable=SC3019
    USBPORTCFG=$(($((2 ** $((USBMAXIDX + 1)) - 1)) ^ $((2 ** USBMINIDX - 1))))
    OVERLAPMASK=$((USBPORTCFG & NONUSBMASK))
    if [ ${OVERLAPMASK} -ne 0 ]; then
      USBPORTCFG=$((USBPORTCFG ^ OVERLAPMASK))
      _log "fix usbportcfg overlap: clear mask=0x$(printf '%x' ${OVERLAPMASK})"
    fi
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  else
    USBPORTCFG=0
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  fi
  if _check_user_conf "esataportcfg"; then
    ESATAPORTCFG=$(($(__get_conf_kv esataportcfg)))
    printf 'get esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
  else
    __set_conf_kv "esataportcfg" "$(printf "0x%.2x" ${ESATAPORTCFG})"
    printf 'set esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
    __set_conf_kv "eunitseq" "$(IFS=, _itol ${ESATAPORTCFG})"
  fi
  if _check_user_conf "internalportcfg"; then
    INTERNALPORTCFG=$(($(__get_conf_kv internalportcfg)))
    printf 'get internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  else
    # shellcheck disable=SC3019
    INTERNALPORTCFG=$(($((2 ** MAXDISKS - 1)) ^ USBPORTCFG ^ ESATAPORTCFG))
    __set_conf_kv "internalportcfg" "$(printf "0x%.2x" ${INTERNALPORTCFG})"
    printf 'set internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  fi

  if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
    MAXDISKS=26
    printf "set maxdisks=26 [%d]\n" "${MAXDISKS}"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS}"
  printf "set maxdisks=%d\n" "${MAXDISKS}"

  COUNT=0
  echo "[pci]" >/etc/extensionPorts
  for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
    [ ! -e "${F}" ] && continue
    PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
    PCIEPATH="$(echo "${PHYSDEVPATH}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
    if [ -z "${PCIEPATH}" ]; then
      _log "unknown: ${F}"
      continue
    fi
    if [ "${BOOTDISK_PHYSDEVPATH}" = "${PHYSDEVPATH}" ] || [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ]; then
      _log "bootloader: ${F}"
      continue
    fi
    if grep -q "${PCIEPATH}" /etc/extensionPorts; then
      _log "already: ${F}, An nvme controller only recognizes one disk"
      continue
    fi
    COUNT=$((COUNT + 1))
    echo "pci${COUNT}=\"${PCIEPATH}\"" >>/etc/extensionPorts
  done

  if [ "${COUNT}" -gt 0 ]; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"
    #__set_conf_kv "support_write_cache" "yes"
  fi
}

nondtUpdate() {
  _log nondtUpdate "$*"
  F="$(basename "${1:-}" 2>/dev/null)"
  if [ -z "${F}" ]; then
    _log "No disk found, triggering full nondtModel"
    nondtModel
    return $?
  fi

  nondtModel
  return 0
}

if type flock >/dev/null 2>&1 && type trap >/dev/null 2>&1; then
  LOCKFILE="/var/run/disks.lock"
  exec 3>"$LOCKFILE"
  flock -w 60 3 || {
    _log "Failed to acquire lock after 60 seconds. Exiting."
    exit 1
  }
  trap 'flock -u 3; rm -f "$LOCKFILE"' EXIT INT TERM HUP
fi

[ -z "$(/sbin/blkid -L ARC3 2>/dev/null)" ] && checkAlldisk

BOOTDISK_PART3_PATH="$(/sbin/blkid -L ARC3 2>/dev/null)"
if [ -n "${BOOTDISK_PART3_PATH}" ]; then
  BOOTDISK_PART3_MAJORMINOR="$(stat -c '%t:%T' "${BOOTDISK_PART3_PATH}" | awk -F: '{printf "%d:%d", strtonum("0x" $1), strtonum("0x" $2)}')"
  BOOTDISK_PART3="$(awk -F= '/DEVNAME/ {print $2}' "/sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent" 2>/dev/null)"
fi

if [ -n "${BOOTDISK_PART3}" ]; then
  BOOTDISK="$(basename "$(dirname /sys/block/*/${BOOTDISK_PART3} 2>/dev/null)" 2>/dev/null)"
  BOOTDISK_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "/sys/block/${BOOTDISK}/uevent" 2>/dev/null)"
fi

if [ -n "${BOOTDISK}" ]; then
  BOOTDISK_PCIEPATH="$(grep 'pciepath' /sys/block/${BOOTDISK}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
  BOOTDISK_ATAPORT="$(grep 'ata_port_no' /sys/block/${BOOTDISK}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
  if [ -z "${BOOTDISK_PCIEPATH}" ] && [ -n "${BOOTDISK_PHYSDEVPATH}" ]; then
    BOOTDISK_PCIEPATH="$(echo "${BOOTDISK_PHYSDEVPATH}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' | tail -1)"
  fi
fi

echo "BOOTDISK=${BOOTDISK}"
echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"
echo "BOOTDISK_PCIEPATH=${BOOTDISK_PCIEPATH}"
echo "BOOTDISK_ATAPORT=${BOOTDISK_ATAPORT}"

checkSynoboot

case ${1} in
  "--create")
    if [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
      dtModel
    else
      nondtModel
    fi
    ;;
  "--update")
    if [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
      if [ ! -f "/etc/user_model.dts" ]; then
        dtUpdate "${2:-}"
      fi
    else
      if ! _check_user_conf "usbportcfg" || ! _check_user_conf "esataportcfg" || ! _check_user_conf "internalportcfg"; then
        nondtUpdate "${2:-}"
      fi
    fi
    ;;
  *)
    echo "Usage: $0 [--create|--update]"
    echo
    echo "       --create: create dts file and update synoinfo.conf"
    echo "       --update: update dts file and update synoinfo.conf"
    exit 1
    ;;
esac

exit 0
