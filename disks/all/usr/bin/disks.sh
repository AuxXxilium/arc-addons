#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

ROOT_PATH=""
GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

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
  [ -f "/addons/synoinfo.conf" ] && UCONF="/addons/synoinfo.conf" || UCONF="/usr/arc/addons/synoinfo.conf"
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
  for F in /sys/block/*; do
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
  for F in /sys/bus/usb/devices/usb*; do
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
      echo "    compatible = \"Synology\";"
      echo "    model = \"\";"
      echo "    version = <0x01>;"
      echo "    power_limit = \"\";"
    } >"${DEST}"

    # SATA ports
    COUNT=0

    HDDSORT="$(grep -wq "hddsort" /proc/cmdline 2>/dev/null && echo "true" || echo "false")"

    for F in /sys/block/sata*; do
      [ ! -e "${F}" ] && continue
      PCIEPATH="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      ATAPORT="$(grep 'ata_port_no' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      if [ -z "${PCIEPATH}" ] || [ -z "${ATAPORT}" ]; then
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
          if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] && [ "${BOOTDISK_ATAPORT}" = "${I}" ]; then
            _log "bootloader: ${F}"
            continue
          fi
          COUNT=$((COUNT + 1))
          {
            echo "    internal_slot@${COUNT} {"
            echo "        protocol_type = \"sata\";"
            echo "        ahci {"
            echo "            pcie_root = \"${PCIEPATH}\";"
            echo "            ata_port = <0x$(printf '%02X' ${I})>;"
            echo "        };"
            echo "    };"
          } >>"${DEST}"
        done
      else
        if [ "${BOOTDISK_PCIEPATH}" = "${PCIEPATH}" ] && [ "${BOOTDISK_ATAPORT}" = "${ATAPORT}" ]; then
          _log "bootloader: ${F}"
          continue
        fi
        COUNT=$((COUNT + 1))
        {
          echo "    internal_slot@${COUNT} {"
          echo "        protocol_type = \"sata\";"
          echo "        ahci {"
          echo "            pcie_root = \"${PCIEPATH}\";"
          echo "            ata_port = <0x$(printf '%02X' ${ATAPORT})>;"
          echo "        };"
          echo "    };"
        } >>"${DEST}"
      fi
    done

    # NVME ports
    COUNT=0
    POWER_LIMIT=""
    for F in /sys/block/nvme*; do
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
      {
        echo "    nvme_slot@${COUNT} {"
        echo "        pcie_root = \"${PCIEPATH}\";"
        echo "        port_type = \"ssdcache\";"
        echo "    };"
      } >>"${DEST}"
    done
    [ -n "${POWER_LIMIT}" ] && sed -i "s/power_limit = .*/power_limit = \"${POWER_LIMIT}\";/" "${DEST}" || sed -i '/power_limit/d' "${DEST}"

    # USB ports
    COUNT=0
    for I in $(getUsbPorts); do
      COUNT=$((COUNT + 1))
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
    rm -vf "${DEST}"
    cp -vpf /etc/model.dtb /etc.defaults/model.dtb
    cp -vpf /etc/model.dtb /run/model.dtb
    /usr/syno/bin/syno_slot_mapping
    # Check if the storagepanel.service is existing
    [ -f "/usr/lib/systemd/system/storagepanel.service" ] && systemctl restart storagepanel.service
    return 0
  else
    _log "dtc error"
    rm -vf "${DEST}"
    cp -vpf /etc.defaults/model.dtb /etc/model.dtb
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

  MAXDISKS=0
  USBPORTCFG=0
  ESATAPORTCFG=0
  INTERNALPORTCFG=0

  hasUSB=false
  USBMINIDX=99
  USBMAXIDX=00
  for F in /sys/block/sd*; do
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

  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    printf "get maxdisks=%d\n" "${MAXDISKS}"
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
  for F in /sys/block/nvme*; do
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

  _log "TODO: ${F}"
  return 0
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