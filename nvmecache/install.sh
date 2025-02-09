#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

check_model() {
  MODELS="DS918+ RS1619xs+ DS1019+ DS718+ DS1621xs+"
  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"

  if ! echo "${MODELS}" | grep -wq "${MODEL}"; then
    echo "${MODEL} is not supported nvmecache addon!"
    exit 0
  fi
}

install_patches() {
  echo "Installing addon nvmecache - patches"

  BOOTDISK_PART3_PATH="$(blkid -L ARC3 2>/dev/null)"
  [ -n "${BOOTDISK_PART3_PATH}" ] && BOOTDISK_PART3_MAJORMINOR="$((0x$(stat -c '%t' "${BOOTDISK_PART3_PATH}"))):$((0x$(stat -c '%T' "${BOOTDISK_PART3_PATH}")))" || BOOTDISK_PART3_MAJORMINOR=""
  [ -n "${BOOTDISK_PART3_MAJORMINOR}" ] && BOOTDISK_PART3="$(cat /sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent 2>/dev/null | grep 'DEVNAME' | cut -d'=' -f2)" || BOOTDISK_PART3=""

  [ -n "${BOOTDISK_PART3}" ] && BOOTDISK="$(ls -d /sys/block/*/${BOOTDISK_PART3} 2>/dev/null | cut -d'/' -f4)" || BOOTDISK=""
  [ -n "${BOOTDISK}" ] && BOOTDISK_PHYSDEVPATH="$(cat /sys/block/${BOOTDISK}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" || BOOTDISK_PHYSDEVPATH=""

  echo "BOOTDISK=${BOOTDISK}"
  echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"

  rm -f /etc/nvmePorts
  for P in $(ls -d /sys/block/nvme* 2>/dev/null); do
    if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2)" ]; then
      echo "bootloader: ${P}"
      continue
    fi
    PCIEPATH="$(cat ${P}/uevent 2>/dev/null | grep 'PHYSDEVPATH' | cut -d'=' -f2 | awk -F'/' '{if (NF == 4) print $NF; else if (NF > 4) print $(NF-1)}')"
    if [ -n "${PCIEPATH}" ]; then
      grep -q "${PCIEPATH}" /etc/nvmePorts && continue
      echo "${PCIEPATH}" >> /etc/nvmePorts
    fi
  done
  [ -f /etc/nvmePorts ] && cat /etc/nvmePorts
}

install_late() {
  echo "Installing addon nvmecache - late"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  if [ ! -f /etc/nvmePorts ]; then
    echo "/etc/nvmePorts does not exist"
    exit 0
  fi

  SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"

  # Replace the device path.
  cp -pf "${SO_FILE}.bak" "${SO_FILE}"
  sed -i "s/0000:00:13.1/0000:99:99.0/; s/0000:00:03.2/0000:99:99.0/; s/0000:00:14.1/0000:99:99.0/; s/0000:00:01.1/0000:99:99.0/" "${SO_FILE}"
  sed -i "s/0000:00:13.2/0000:99:99.1/; s/0000:00:03.3/0000:99:99.1/; s/0000:00:99.9/0000:99:99.1/; s/0000:00:01.0/0000:99:99.1/" "${SO_FILE}"

  idx=0
  for N in $(cat /etc/nvmePorts 2>/dev/null); do
    echo "${idx} - ${N}"
    if [ ${idx} -eq 0 ]; then
      sed -i "s/0000:99:99.0/${N}/g" "${SO_FILE}"
    elif [ ${idx} -eq 1 ]; then
      sed -i "s/0000:99:99.1/${N}/g" "${SO_FILE}"
    else
      break
    fi
    idx=$((idx + 1))
  done
}

uninstall_addon() {
  echo "Uninstalling addon nvmecache - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libsynonvme.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"
}

case "${1}" in
  patches)
    check_model
    install_patches
    ;;
  late)
    check_model
    install_late
    ;;
  uninstall)
    uninstall_addon
    ;;
  *)
    exit 0
    ;;
esac