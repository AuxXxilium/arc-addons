#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "early" ]; then
  echo "Installing addon misc - ${1}"

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/2d6520302e39/2d6520312e32/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

elif [ "${1}" = "patches" ]; then
  # getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -Eo 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -wq "${TTYN}" && continue
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Starting getty on ${TTYN}"
      if [ -n "${BAUD}" ]; then
        /usr/sbin/getty -L "${TTYN}" "${BAUD}" linux &
      else
        /usr/sbin/getty -L "${TTYN}" linux &
      fi
    fi
  done

  # network
  if grep -q 'network.' /proc/cmdline; then
    for I in $(grep -Eo 'network.[0-9a-fA-F:]{12,17}=[^ ]*' /proc/cmdline); do
      MACR="$(echo "${I}" | cut -d. -f2 | cut -d= -f1 | sed 's/://g; s/.*/\L&/')"
      IPRS="$(echo "${I}" | cut -d= -f2)"
      for F in /sys/class/net/eth*; do
        [ ! -e "${F}" ] && continue
        ETH="$(basename "${F}")"
        MACX=$(cat "/sys/class/net/${ETH}/address" 2>/dev/null | sed 's/://g; s/.*/\L&/')
        if [ "${MACR}" = "${MACX}" ]; then
          echo "Setting IP for ${ETH} to ${IPRS}"
          F="/etc/sysconfig/network-scripts/ifcfg-${ETH}"
          /bin/set_key_value "${F}" BOOTPROTO "static"
          /bin/set_key_value "${F}" "IPADDR" "$(echo "${IPRS}" | cut -d/ -f1)"
          /bin/set_key_value "${F}" "NETMASK" "$(echo "${IPRS}" | cut -d/ -f2)"
          /bin/set_key_value "${F}" "GATEWAY" "$(echo "${IPRS}" | cut -d/ -f3)"
          /etc/rc.network restart ${ETH} >/dev/null 2>&1
          [ -n "$(echo "${IPRS}" | cut -d/ -f4)" ] && /etc/rc.network_routing "$(echo "${IPRS}" | cut -d/ -f4)" &
        fi
      done
    done
  fi

elif [ "${1}" = "rcExit" ]; then
  echo "Installing addon misc - ${1}"

  # enable telnet
  sed -i 's/^root:x:0:0/root::0:0/' /etc/passwd
  inetd

  # invalid_disks
  # method 1
  SH_FILE="/usr/syno/share/get_hcl_invalid_disks.sh"
  [ -f "${SH_FILE}" ] && cp -pf "${SH_FILE}" "${SH_FILE}.bak" && printf '#!/bin/sh\nexit 0\n' >"${SH_FILE}"
  # method 2
  # while true; do [ ! -f "/tmp/installable_check_pass" ] && touch "/tmp/installable_check_pass"; sleep 1; done &  # using a while loop in case DSM is running in a VM

  # error message
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    sed -i 's/c("welcome","desc_install")/"Error: The bootloader disk is not successfully mounted, the installation will fail."/' /usr/syno/web/main.js 2>/dev/null
  fi

  # disable DisabledPortDisks
  sed -i 's/^DisabledPortDisks=.*$/DisabledPortDisks=""/' /usr/syno/web/webman/get_state.cgi 2>/dev/null

  # recovery
  if grep -wq "recovery" /proc/cmdline 2>/dev/null && [ -x /usr/syno/web/webman/recovery.cgi ]; then
    /usr/syno/web/webman/recovery.cgi
  fi

elif [ "${1}" = "late" ]; then
  echo "Installing addon misc - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  # cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  echo "Killing ttyd ..."
  /usr/bin/killall ttyd 2>/dev/null || true

  echo "Killing dufs ..."
  /usr/bin/killall dufs 2>/dev/null || true

  # synoinfo.conf
  cp -vpf "/addons/synoinfo.conf" /tmpRoot/usr/arc/addons/synoinfo.conf
  for KEY in $(cat "/addons/synoinfo.conf" 2>/dev/null | cut -d= -f1); do
    [ -z "${KEY}" ] && continue
    VALUE="$(/bin/get_key_value /etc/synoinfo.conf "${KEY}")" # Do not use the value in /addons/synoinfo.conf
    echo "Setting ${KEY} to ${VALUE}"
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "${KEY}" "${VALUE}"; done
  done

  # CPU performance scaling
  mount -t sysfs sysfs /sys
  modprobe acpi-cpufreq
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf ]; then
    CPUFREQ=$(ls -l /sys/devices/system/cpu/cpufreq/*/* 2>/dev/null | wc -l)
    if [ ${CPUFREQ} -eq 0 ]; then
      echo "CPU does NOT support CPU Performance Scaling, disabling"
      sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
    else
      echo "CPU supports CPU Performance Scaling, enabling"
      sed -i 's/^# acpi-cpufreq/acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
      cp -vpf /usr/lib/modules/cpufreq_* /tmpRoot/usr/lib/modules/
    fi
  fi
  modprobe -r acpi-cpufreq
  umount /sys

  # crypto-kernel
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]; then
    # crc32c-intel
    if grep flags /proc/cpuinfo 2>/dev/null | grep -wq sse4_2; then
      echo "CPU Supports SSE4.2, crc32c-intel should load"
    else
      echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"
      sed -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi

    # aesni-intel
    if grep flags /proc/cpuinfo 2>/dev/null | grep -wq aes; then
      echo "CPU Supports AES, aesni-intel should load"
    else
      echo "CPU does NOT support AES, aesni-intel will not load, disabling"
      for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_aesni_intel" "no"; done
      sed -i 's/^aesni-intel/# aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # Nvidia GPU
  if grep -iq 10de /proc/bus/pci/devices 2>/dev/null; then
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_nvidia_gpu" "yes"; done
    [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ] && sed -i 's/^# nvidia/nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
  else
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_nvidia_gpu" "no"; done
    [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ] && sed -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
  fi

  # sdcard
  [ ! -f /tmpRoot/usr/lib/udev/script/sdcard.sh.bak ] && cp -vpf /tmpRoot/usr/lib/udev/script/sdcard.sh /tmpRoot/usr/lib/udev/script/sdcard.sh.bak
  printf '#!/usr/bin/env sh\nexit 0\n' >/tmpRoot/usr/lib/udev/script/sdcard.sh

  # beep
  cp -vpf /usr/bin/beep /tmpRoot/usr/bin/beep
  cp -vpdf /usr/lib/libubsan.so* /tmpRoot/usr/lib/
  cp -vpf /usr/bin/loader-reboot.sh /tmpRoot/usr/bin/loader-reboot.sh
  cp -vpf /usr/bin/grub-editenv /tmpRoot/usr/bin/grub-editenv
  cp -vpf /usr/bin/PatchELFSharp /tmpRoot/usr/bin/PatchELFSharp
  cp -vpf /usr/bin/sveinstaller /tmpRoot/usr/bin/sveinstaller
  # [ ! -f /tmpRoot/usr/syno/bin/synoschedtool.bak ] && cp -vpf /tmpRoot/usr/syno/bin/synoschedtool /tmpRoot/usr/syno/bin/synoschedtool.bak
  # printf '#!/usr/bin/env sh\ncase "${1}" in\n  --beep)\n  beep -r ${2}\n  ;;\n  *)\n    /usr/syno/bin/synoschedtool.bak "$@"  ;;\nesac\n' >/tmpRoot/usr/syno/bin/synoschedtool

  # service
  # SynoInitEth syno-oob-check-status syno_update_disk_logs
  sed -i 's|ExecStart=/|ExecStart=-/|g' /tmpRoot/usr/lib/systemd/system/SynoInitEth.service 2>/dev/null
  sed -i 's|ExecStart=/|ExecStart=-/|g' /tmpRoot/usr/lib/systemd/system/syno-oob-check-status.service 2>/dev/null
  sed -i 's|ExecStart=/|ExecStart=-/|g' /tmpRoot/usr/lib/systemd/system/syno_update_disk_logs.service 2>/dev/null

  # getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -Eo 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -wq "${TTYN}" && continue

    mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Make getty\@${TTYN}.service"
      cp -vpf /tmpRoot/usr/lib/systemd/system/serial-getty\@.service /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      sed -i "s|^ExecStart=.*|ExecStart=-/sbin/agetty %I ${BAUD:-115200} linux|" /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
      ln -vsf /usr/lib/systemd/system/getty\@${TTYN}.service /tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@${TTYN}.service
    fi
  done
  # arc-misc
  cp -vpf /usr/bin/arc-misc.sh /tmpRoot/usr/bin/arc-misc.sh

  DEST="/tmpRoot/usr/lib/systemd/system/arc-misc.service"
  {
    echo "[Unit]"
    echo "Description=arc-misc daemon"
    echo "After=multi-user.target"
    echo "After=scemd.service rc-network.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=-/usr/bin/arc-misc.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-misc.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-misc.service

  # arc-once
  cp -vpf /usr/bin/arc-misc.sh /tmpRoot/usr/bin/arc-misc.sh
  DEST="/tmpRoot/usr/lib/systemd/system/arc-once.service"
  {
    echo "[Unit]"
    echo "Description=ARC addon arc-once daemon"
    echo "After=multi-user.target"
    echo "After=scemd.service rc-network.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=-/usr/bin/arc-once.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-once.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-once.service

  # vmtools
  if [ -d "/tmpRoot/var/packages/open-vm-tools" ] && [ ! -f "/tmpRoot/usr/arc/addons/vmtools.sh" ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/open-vm-tools/conf/privilege >/dev/null 2>&1 || true
  fi

  # qemu-ga
  if [ -d "/tmpRoot/var/packages/qemu-ga" ] && [ ! -f "/tmpRoot/usr/arc/addons/vmtools.sh" ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/qemu-ga/conf/privilege >/dev/null 2>&1 || true
  fi

fi
exit 0