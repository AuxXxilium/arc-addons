#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and PeterSuh-Q3 <https://github.com/PeterSuh-Q3>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set_key_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  [ ! -f "$file" ] && touch "$file"

  value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  if grep -q "^${key}=" "$file"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

ROOT_PATH=""
GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
if [ -x "/bin/set_key_value" ]; then
  SKV="/bin/set_key_value"
elif [ -x "/usr/syno/bin/synosetkeyvalue" ]; then
  SKV="/usr/syno/bin/synosetkeyvalue"
else
  SKV="set_key_value"
fi

# Logging
_log() {
  echo "disks: $*"
  /bin/logger -p "error" -t "disks" "$@"
}

# Get values in synoinfo.conf
# Args: $1 key
__get_conf_kv() {
  "${GKV}" "${ROOT_PATH}/etc.defaults/synoinfo.conf" "${1}" 2>/dev/null
}

# Replace/add values in synoinfo.conf
# Args: $1 key, $2 val
__set_conf_kv() {
  for F in "${ROOT_PATH}/etc/synoinfo.conf" "${ROOT_PATH}/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "${1}" "${2}"; done
}

# Check if the user has customized the key
# Args: $1 key
_check_user_conf() {
  [ -f "/addons/synoinfo.conf" ] && UCONF="/addons/synoinfo.conf" || UCONF="/usr/rr/addons/synoinfo.conf"
  grep -Eq "^${1}=" "${UCONF}" 2>/dev/null
}

# Check if the raid has been completed currently
# Returns: 0 if yes, 1 if no
_check_rootraidstatus() {
  [ "$(__get_conf_kv supportraid)" = "yes" ] || return 1
  [ -f "/sys/block/md0/md/array_state" ] || return 1
  STATE=$(cat "/sys/block/md0/md/array_state" 2>/dev/null)
  case ${STATE} in
  "clear" | "inactive" | "suspended" | "readonly" | "read-auto") return 1 ;;
  esac
  return 0
}

# Convert disk name to integer
# Args: $1 disk name
_atoi() {
  DISKNAME=${1}
  NUM=0
  IDX=0
  while [ ${IDX} -lt ${#DISKNAME} ]; do
    N=$(($(printf '%d' "'$(expr substr "${DISKNAME}" $((${IDX} + 1)) 1)") - $(printf '%d' "'a") + 1))
    BIT=$(($(expr length "${DISKNAME}") - 1 - ${IDX}))
    # shellcheck disable=SC3019
    NUM=$((NUM + (BIT == 0 ? N : 26 ** BIT * N)))
    IDX=$((IDX + 1))
  done
  echo $((NUM - 1))
}

# Convert integer to disk name
# Args: $1 disks mask
_itol() {
  IFS="${IFS:- }"
  NUM="$(echo $((${1:-"-1"})))"
  IDX=0
  DISKLIST=""
  while [ ${NUM} -gt 0 ]; do
    if [ "$((NUM & 1))" = 1 ]; then
      case $((IDX / 26)) in
      0) dev="$(printf sd\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;;                                                              # sda-z
      *) dev="$(printf sd\\x"$(printf "%x" "$((IDX / 26 - 1 + $(printf '%d' "'a")))")"\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;; # sdaa-zz
      esac
      DISKLIST="${DISKLIST:+${DISKLIST}${IFS}}${dev}"
    fi
    NUM=$((NUM >> 1))
    IDX=$((IDX + 1))
  done
  echo "${DISKLIST}"
}

# Check if the disk is lossed
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

# Check if the disk is a boot disk
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

# USB ports
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

# check dts slot mapping instead of /usr/syno/bin/syno_slot_mapping
_chk_slot_mapping() {

  echo "Internal Disk:"
  i=1
  for dev in $(ls -d /sys/block/sata* 2>/dev/null | sort -t 'a' -k 3n); do
    devname=$(basename $dev)
    echo "$(printf '%02d' $i): /dev/$devname"
    i=$((i+1))
  done
  echo
  
  echo "Internal SSD Cache:"
  i=1
  for dev in /sys/block/nvme*n*; do
    devname=$(basename $dev)
    echo "$(printf '%02d' $i): /dev/$devname"
    i=$((i+1))
  done

}

# DT model
dtModel() {
  _log dtModel

  DEST="/etc/model.dts"
  [ -f "/addons/model.dts" ] && cp -vpf "/addons/model.dts" "${DEST}"
  if [ ! -f "${DEST}" ]; then # Users can put their own dts.  
    mkdir -p "$(dirname "${DEST}" 2>/dev/null)"
    {
      echo "/dts-v1/;"
      echo "/ {"
      echo "    #address-cells = <1>;"
      echo "    #size-cells = <1>;"      
      echo "    compatible = \"Synology\";"
      echo "    model = \"\";"
      echo "    version = <0x01>;"
      echo "    power_limit = \"\";"
    } >"${DEST}"

    # SATA ports
    COUNT=0
    REG_COUNT=0
    HDDSORT="$(grep -wq "hddsort" /proc/cmdline 2>/dev/null && echo "true" || echo "false")"

    for F in $(LC_ALL=C printf '%s\n' /sys/block/sata* | sort -V); do
      [ ! -e "${F}" ] && continue
      PCIEPATH="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      ATAPORT="$(grep 'ata_port_no' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      DRIVER="$(cat "${F}/device/syno_block_info" 2>/dev/null | grep 'driver' | cut -d'=' -f2)"
      if [ -z "${PCIEPATH}" ] || [ -z "${DRIVER}" ]; then
        _log "unknown: ${F}"
        continue
      fi
      if [ "${CONTPCI}" = "${PCIEPATH}" ]; then
        continue
      fi
      CONTPCI=""
      # shellcheck disable=SC2046
      PORTNUM=$(ls -ld /sys/devices/pci0000:00/*$(echo "${PCIEPATH}" | sed 's/,/\/*:/g')/ata* 2>/dev/null | wc -l)
      if [ "${HDDSORT}" = "true" ] && [ "${PORTNUM}" -gt 0 ]; then
        CONTPCI=${PCIEPATH}
        for I in $(seq 0 $((${PORTNUM} - 1))); do
          if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] && ([ -z "${ATAPORT}" ] || [ "${BOOTDISK_ATAPORT}" = "${I}" ]); then
            _log "bootloader: ${F}"
            continue
          fi
          COUNT=$((COUNT + 1))
          REG_COUNT=$((REG_COUNT + 1))
          {
            echo "    internal_slot@${COUNT} {"
            echo "        reg = <0x$(printf '%02X' ${REG_COUNT}) 0x00>;"            
            echo "        protocol_type = \"sata\";"
            echo "        ${DRIVER} {"
            echo "            pcie_root = \"${PCIEPATH}\";"
            [ -n "${ATAPORT}" ] && echo "            ata_port = <0x$(printf '%02X' ${I})>;"
            echo "            internal_mode;"
            echo "        };"
            echo "    };"
          } >>"${DEST}"
        done
      else
        if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] && ([ -z "${ATAPORT}" ] || [ "${BOOTDISK_ATAPORT}" = "${ATAPORT}" ]); then
          _log "bootloader: ${F}"
          continue
        fi
        COUNT=$((COUNT + 1))
        REG_COUNT=$((REG_COUNT + 1))
        {
          echo "    internal_slot@${COUNT} {"
          echo "        reg = <0x$(printf '%02X' ${REG_COUNT}) 0x00>;"                      
          echo "        protocol_type = \"sata\";"
          echo "        ${DRIVER} {"
          echo "            pcie_root = \"${PCIEPATH}\";"
          [ -n "${ATAPORT}" ] && echo "            ata_port = <0x$(printf '%02X' ${ATAPORT})>;"
          echo "            internal_mode;"
          echo "        };"
          echo "    };"
        } >>"${DEST}"
      fi
    done

    # NVME ports
    COUNT=0
    POWER_LIMIT=""
    for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
      [ ! -e "${F}" ] && continue
      PCIEPATH="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      if [ -z "${PCIEPATH}" ]; then
        _log "unknown: ${F}"
        continue
      fi
      if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ]; then
        _log "bootloader: ${F}"
        continue
      fi
      grep -q "pcie_root = \"${PCIEPATH}\";" ${DEST} && continue # An nvme controller only recognizes one disk
      [ $((${#POWER_LIMIT} + 2)) -gt 30 ] && break               # POWER_LIMIT string length limit 30 characters
      POWER_LIMIT="${POWER_LIMIT:+${POWER_LIMIT},}0"
      COUNT=$((COUNT + 1))
      REG_COUNT=$((REG_COUNT + 1))
      {
        echo "    nvme_slot@${COUNT} {"
        echo "        reg = <0x$(printf '%02X' ${REG_COUNT}) 0x00>;"
        echo "        pcie_root = \"${PCIEPATH}\";"
        echo "        port_type = \"ssdcache\";"
        echo "    };"
      } >>"${DEST}"
    done
    [ -n "${POWER_LIMIT}" ] && sed -i "s/power_limit = .*/power_limit = \"${POWER_LIMIT}\";/" "${DEST}" || sed -i '/power_limit/d' "${DEST}"

    # USB ports
    for I in $(getUsbPorts); do
      COUNT=$((COUNT + 1))
      REG_COUNT=$((REG_COUNT + 1))
      {
        echo "    usb_slot@${COUNT} {"
        echo "      reg = <0x$(printf '%02X' ${REG_COUNT}) 0x00>;"
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

  # fix pcie_root prefix
  _release=$(/bin/uname -r)
  if [ "$(/bin/echo "${_release%%[-+]*}" | /usr/bin/cut -d'.' -f1)" -lt 5 ]; then
    sed -i 's/"0000:00:/"00:/g' "${DEST}"
  else
    sed -i 's/"00:/"0000:00:/g' "${DEST}"
  fi

  # fix model name
  UNIQUE=$(__get_conf_kv unique)
  sed -i "0,/version = .*;/s/model = \".*\";/model = \"${UNIQUE}\";/" "${DEST}"

  MAXDISKS=$(grep -c "internal_slot@" "${DEST}" 2>/dev/null)
  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    _log "get maxdisks=${MAXDISKS:-0}"
  else
    # fix isSingleBay issue: if maxdisks is 1, there is no create button in the storage panel
    # [ ${MAXDISKS} -le 2 ] && MAXDISKS=4
    [ "${MAXDISKS:-0}" -lt 26 ] && MAXDISKS=26
  fi
  # Raidtool will read maxdisks, but when maxdisks is greater than 27, formatting error will occur 8%.
  if ! _check_rootraidstatus && [ "${MAXDISKS:-0}" -gt 26 ]; then
    MAXDISKS=26
    _log "set maxdisks=26 [${MAXDISKS:-0}]"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS:-0}"
  _log "maxdisks=${MAXDISKS:-0}"

  if grep -q "nvme_slot@" "${DEST}" 2>/dev/null; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"  # block nvmesystem addon
    #__set_conf_kv "support_write_cache" "yes"
  fi

  dtc -I dts -O dtb "${DEST}" >/etc/model.dtb
  if [ $? -eq 0 ]; then
    _log "dtc success"
    #rm -vf "${DEST}"
    #cp -vpf /etc/model.dtb /etc.defaults/model.dtb
    cp -vpf /etc/model.dtb /run/model.dtb
    _chk_slot_mapping
    # Check if the storagepanel.service is existing
    [ -f "/usr/lib/systemd/system/storagepanel.service" ] && systemctl restart storagepanel.service
    return 0
  else
    _log "dtc error"
    #rm -vf "${DEST}"
    #cp -vpf /etc.defaults/model.dtb /etc/model.dtb
    return 1
  fi
}

# DT model update
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
    _log "unknown: ${F}"
    return 1
  fi

  TEMP_DTS="/tmp/model.dts"
  dtc -I dtb -O dts /etc/model.dtb >"${TEMP_DTS}"
  sata_slot_find="$(sed -n "/pcie_root = \"${PCIEPATH}\";/{N;/ata_port = <0x$(printf '%02X' ${ATAPORT})>;/p}" "${TEMP_DTS}" 2>/dev/null)"
  nvme_slot_find="$(sed -n "/pcie_root = \"${PCIEPATH}\";/{N;/port_type = \"ssdcache\";/p}" "${TEMP_DTS}" 2>/dev/null)"
  usb_slot_find="$(sed -n "/usb3 {/{N;/usb_port = \"${USBPORT}\";/p}" "${TEMP_DTS}" 2>/dev/null)"
  rm -f "${TEMP_DTS}"
  if [ -n "${sata_slot_find}" ] || [ -n "${nvme_slot_find}" ] || [ -n "${usb_slot_find}" ]; then
    _log "${F} is in the model.dts"
    return 0
  fi

  dtModel
}

# non-DT model
nondtModel() {
  _log nondtModel

  # Wait for asynchronous HBA probes (mpt3sas/megaraid_sas/hpsa) to complete
  # before enumerating /sys/block/sd* so all HBA disks are counted.
  if type udevadm >/dev/null 2>&1; then
    udevadm settle --timeout=30 2>/dev/null
  fi

  MAXDISKS=0
  USBPORTCFG=0
  ESATAPORTCFG=0
  INTERNALPORTCFG=0

  hasUSB=false
  USBMINIDX=99
  USBMAXIDX=00
  MAXNONUSBIDX=-1
  for F in $(LC_ALL=C printf '%s\n' /sys/block/sd* | sort -V); do
    [ ! -e "${F}" ] && continue
    IDX=$(_atoi "$(echo "${F}" | sed -E 's/^.*\/sd(.*)$/\1/')")
    [ $((${IDX} + 1)) -ge ${MAXDISKS} ] && MAXDISKS=$((${IDX} + 1))
    if grep "PHYSDEVPATH" "${F}/uevent" 2>/dev/null | grep -q "usb"; then
      if [ "${hasUSB}" = "false" ]; then
        [ ${IDX} -lt ${USBMINIDX} ] && USBMINIDX=${IDX}
        [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
        hasUSB=true
      else
        [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
      fi
    else
      [ ${IDX} -gt ${MAXNONUSBIDX} ] && MAXNONUSBIDX=${IDX}
    fi
  done
  # Reserve 6 USB slots minimum, but never across indices occupied by
  # non-USB disks (AHCI/HBA). When USB sits at a middle index and HBA
  # disks are at higher indices, extending USB range would swallow HBA
  # bits and mis-classify them as USB (breaks HBA disk recognition).
  if [ "${hasUSB}" = "false" ]; then
    USBMINIDX=$((${MAXNONUSBIDX} + 1))
    [ ${USBMINIDX} -lt ${MAXDISKS} ] && USBMINIDX=${MAXDISKS}
    USBMAXIDX=$((${USBMINIDX} + 6 - 1))
  elif [ ${MAXNONUSBIDX} -lt ${USBMINIDX} ]; then
    # No non-USB disk above USB range -> safe to extend to 6 slots
    [ $((${USBMAXIDX} - ${USBMINIDX})) -lt $((6 - 1)) ] && USBMAXIDX=$((${USBMINIDX} + 6 - 1))
  fi
  # else: USB is interleaved with non-USB disks -> keep measured bits only
  [ $((${USBMAXIDX} + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((${USBMAXIDX} + 1))

  if _check_user_conf "maxdisks"; then
    USER_MAXDISKS=$(($(__get_conf_kv maxdisks)))
    # Grow to accommodate actually-detected disks (HBA etc.) even if the
    # vendor-baked synoinfo value is smaller (e.g. DS918+ default=4).
    if [ ${USER_MAXDISKS} -gt ${MAXDISKS} ]; then
      MAXDISKS=${USER_MAXDISKS}
      printf "get maxdisks=%d\n" "${MAXDISKS}"
    else
      printf "use detected maxdisks=%d (user=%d)\n" "${MAXDISKS}" "${USER_MAXDISKS}"
    fi
  else
    # fix isSingleBay issue: if maxdisks is 1, there is no create button in the storage panel
    # [ ${MAXDISKS} -le 2 ] && MAXDISKS=4
    printf "cal maxdisks=%d\n" "${MAXDISKS}"
  fi

  if grep -wq "usbinternal" /proc/cmdline 2>/dev/null; then
    USBPORTCFG=0
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  elif _check_user_conf "usbportcfg"; then
    USBPORTCFG=$(($(__get_conf_kv usbportcfg)))
    printf 'get usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  else
    # shellcheck disable=SC3019
    USBPORTCFG=$(($((2 ** $((${USBMAXIDX} + 1)) - 1)) ^ $((2 ** ${USBMINIDX} - 1))))
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
    INTERNALPORTCFG=$(($((2 ** ${MAXDISKS} - 1)) ^ ${USBPORTCFG} ^ ${ESATAPORTCFG}))
    __set_conf_kv "internalportcfg" "$(printf "0x%.2x" ${INTERNALPORTCFG})"
    printf 'set internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  fi

  # Raidtool will read maxdisks, but when maxdisks is greater than 27, formatting error will occur 8%.
  if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
    MAXDISKS=26
    printf "set maxdisks=26 [%d]\n" "${MAXDISKS}"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS}"
  printf "set maxdisks=%d\n" "${MAXDISKS}"

  # NVME
  COUNT=0
  echo "[pci]" >/etc/extensionPorts
  for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
    [ ! -e "${F}" ] && continue
    PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
    if [ -z "${PHYSDEVPATH}" ]; then
      _log "unknown: ${F}"
      continue
    fi
    if [ "${BOOTDISK_PHYSDEVPATH}" = "${PHYSDEVPATH}" ]; then
      _log "bootloader: ${F}"
      continue
    fi
    PCIEPATH="$(echo "${PHYSDEVPATH}" | awk -F'/' '{if (NF == 4) print $NF; else if (NF > 4) print $(NF-1)}')"
    if grep -q "${PCIEPATH}" /etc/extensionPorts; then
      _log "already: ${F}, An nvme controller only recognizes one disk"
      continue
    fi
    COUNT=$((COUNT + 1))
    echo "pci${COUNT}=\"${PCIEPATH}\"" >>/etc/extensionPorts
  done

  # NVME cache handling for models using libsynonvme.so.1 (make /etc/nvmePorts)
  BOOTDISK_PART3_PATH="$(/sbin/blkid -L ARC3 2>/dev/null)"

  device_name="${BOOTDISK_PART3_PATH#/dev/}"
  [ -n "${BOOTDISK_PART3_PATH}" ] && BOOTDISK_PART3_MAJORMINOR=$(cat "/sys/class/block/${device_name}/dev") || BOOTDISK_PART3_MAJORMINOR=""
  [ -n "${BOOTDISK_PART3_MAJORMINOR}" ] && BOOTDISK_PART3="$(cat "/sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent" 2>/dev/null | grep 'DEVNAME' | cut -d'=' -f2)" || BOOTDISK_PART3=""

  [ -n "${BOOTDISK_PART3}" ] && BOOTDISK="$(ls -d /sys/block/*/${BOOTDISK_PART3} 2>/dev/null | cut -d'/' -f4)" || BOOTDISK=""
  [ -n "${BOOTDISK}" ] && BOOTDISK_PHYSDEVPATH="$(cat "/sys/block/${BOOTDISK}/uevent" 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" || BOOTDISK_PHYSDEVPATH=""

  echo "BOOTDISK=${BOOTDISK}"
  echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"

  # NVMe cache handling for models using libsynonvme.so.1 (make /etc/nvmePorts)
  [ -f /etc/nvmePorts ] && rm -f /etc/nvmePorts
  for P in $(ls -d /sys/block/nvme* 2>/dev/null); do
    if [ -n "${BOOTDISK_PHYSDEVPATH}" -a "${BOOTDISK_PHYSDEVPATH}" = "$(cat ${P}/uevent | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
      echo "bootloader: ${P}"
      continue
    fi
    PCIEPATH=$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | rev | cut -d'/' -f2 | rev )
    if [ -n "${PCIEPATH}" ]; then
      echo "${PCIEPATH}" >>/etc/nvmePorts
    else
      echo "${PCIEPATH} does not support!"
      continue
    fi
  done
  [ -f /etc/nvmePorts ] && cat /etc/nvmePorts

  if [ "${COUNT}" -gt 0 ]; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"  # block nvmesystem addon
    #__set_conf_kv "support_write_cache" "yes"
  fi
}

# non-DT model update
nondtUpdate() {
  _log nondtUpdate "$*"
  F="$(basename "${1:-}" 2>/dev/null)"
  if [ -z "${F}" ]; then
    _log "No disk found"
    return 1
  fi

  # Recompute portcfg/maxdisks when a new disk appears (HBA hot-plug etc.)
  # so internalportcfg/usbportcfg/esataportcfg stay in sync with the
  # actual /sys/block/sd* layout without waiting for a reboot.
  nondtModel
  return 0
}

nvme_late_patch(){
  MODELS="DS918+ RS1619xs+ DS419+ DS1019+ DS719+ DS1621xs+"
  MODEL=$(cat /proc/sys/kernel/syno_hw_version)
  tmpRoot="/tmpRoot"
  if echo ${MODELS} | grep -q ${MODEL}; then
    SO_FILE="${tmpRoot}/usr/lib/libsynonvme.so.1"
    [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"
    cp -vf "${SO_FILE}.bak" "${SO_FILE}"
    num=1
    while read -r N; do
      echo "${num} - ${N}"
      if [ ${num} -eq 1 ]; then
        case "$MODEL" in
          DS918+) sed -i "s/0000:00:13.1/${N}/" "${SO_FILE}" ;;
          RS1619xs+) sed -i "s/0000:00:03.2/${N}/" "${SO_FILE}" ;;
          DS419+|DS1019+) sed -i "s/0000:00:14.1/${N}/" "${SO_FILE}" ;;
          DS719+|DS1621xs+) sed -i "s/0000:00:01.1/${N}/" "${SO_FILE}" ;;
        esac
      elif [ ${num} -eq 2 ]; then
        case "$MODEL" in
          DS918+) sed -i "s/0000:00:13.2/${N}/" "${SO_FILE}" ;;
          RS1619xs+) sed -i "s/0000:00:03.3/${N}/" "${SO_FILE}" ;;
          DS719+|DS1621xs+) sed -i "s/0000:00:01.0/${N}/" "${SO_FILE}" ;;
        esac
      else    
        break  
      fi
      num=$((num+1))
    done < /etc/nvmePorts
  fi
}

# lock
if type flock >/dev/null 2>&1 && type trap >/dev/null 2>&1; then
  LOCKFILE="/var/run/disks.lock"
  exec 3>"$LOCKFILE"
  flock -w 60 3 || {
    _log "Failed to acquire lock after 60 seconds. Exiting."
    exit 1
  }                                                      # 60 seconds timeout
  trap 'flock -u 3; rm -f "$LOCKFILE"' EXIT INT TERM HUP # Release lock on exit or error or signal or hangup
fi

# get the boot disk info
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
fi

echo "BOOTDISK=${BOOTDISK}"
echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"
echo "BOOTDISK_PCIEPATH=${BOOTDISK_PCIEPATH}"
echo "BOOTDISK_ATAPORT=${BOOTDISK_ATAPORT}"

checkSynoboot

###################

case ${1} in
"--create")
  if [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
    dtModel
  else
    nondtModel
  fi
  ;;
"--update")
  ARG2="${2:-}"
  # When the 2nd arg is a directory (e.g. /tmpRoot), treat it as the target
  # root for late-stage propagation: recompute against current /sys/block
  # state and sync the resulting synoinfo.conf / extensionPorts / model.dtb
  # into the DSM rootfs being prepared. Otherwise fall back to the original
  # udev path where ARG2 is a disk DEVNAME.
  if [ -n "${ARG2}" ] && [ -d "${ARG2}" ]; then
    TARGET_ROOT="${ARG2%/}"
    _log "late update target=${TARGET_ROOT}"
    # Do NOT recompute at this stage: /sys/block/sd* may only contain
    # the USB boot disk while AHCI/HBA drivers are still probing, which
    # would trigger the min-6-slot USB extension starting at bit 0 and
    # mis-classify AHCI/HBA disks as USB on later boot. The values
    # produced by --create (run when all disks are visible) are
    # canonical; only propagate them.
    #
    # synoinfo.conf must be MERGED key-by-key (not cp -vpf): the file on
    # the persistent rootfs holds DSM-side user state (auto-update wizard
    # selection, first-boot flags, GUI preferences). A wholesale copy
    # from the ramdisk would clobber those keys on every boot, causing
    # symptoms like the update-options wizard reappearing each reboot.
    # extensionPorts / model.dtb are addon-owned outputs and remain
    # safe to copy whole.
    MANAGED_SYNOINFO_KEYS="maxdisks supportnvme support_m2_pool usbportcfg esataportcfg internalportcfg supportportmappingv2 eunitseq"
    for SF in /etc/synoinfo.conf /etc.defaults/synoinfo.conf; do
      TF="${TARGET_ROOT}${SF}"
      [ ! -f "${SF}" ] && continue
      [ ! -d "$(dirname "${TF}")" ] && continue
      if [ ! -f "${TF}" ]; then
        # Target absent (rare): seed with ramdisk copy so subsequent
        # SKV writes have a base file. User keys not present yet.
        cp -vpf "${SF}" "${TF}"
        _log "seed copy ${SF} -> ${TF}"
        continue
      fi
      for K in ${MANAGED_SYNOINFO_KEYS}; do
        V="$(${GKV} "${SF}" "${K}" 2>/dev/null)"
        # Skip empty: keeps any DSM-baked default when addon did not
        # set the key on this platform (e.g. supportnvme on apollolake
        # without M.2). Empty-write would otherwise stamp "" over it.
        [ -z "${V}" ] && continue
        ${SKV} "${TF}" "${K}" "${V}" >/dev/null 2>&1
        _log "merge ${K}=${V} -> ${TF}"
      done
    done
    for F in /etc/extensionPorts /etc.defaults/extensionPorts \
             /etc/model.dtb /etc.defaults/model.dtb; do
      [ -f "${F}" ] && [ -d "${TARGET_ROOT}$(dirname ${F})" ] && cp -vpf "${F}" "${TARGET_ROOT}${F}"
    done
  elif [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
    if [ ! -f "/etc/user_model.dts" ]; then
      dtUpdate "${ARG2}"
    fi
    cp -vpf /etc/model.dtb /tmpRoot/etc/model.dtb
    cp -vpf /etc/model.dtb /tmpRoot/etc.defaults/model.dtb
  else
    # nvme
    cp -vpf /etc/extensionPorts /tmpRoot/etc/extensionPorts
    cp -vpf /etc/extensionPorts /tmpRoot/etc.defaults/extensionPorts
    if ! _check_user_conf "usbportcfg" || ! _check_user_conf "esataportcfg" || ! _check_user_conf "internalportcfg"; then
      nondtUpdate "${ARG2}"
    fi
  fi
  ;;
"--nvme-late-patch")
  nvme_late_patch
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