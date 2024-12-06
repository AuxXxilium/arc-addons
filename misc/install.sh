#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
if [ "${1}" = "early" ]; then
  echo "Installing addon misc - ${1}"

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -f "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/2d6520302e39/2d6520312e32/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

elif [ "${1}" = "rcExit" ]; then
  echo "Installing addon misc - ${1}"

  mkdir -p /usr/syno/web/webman
  # Create: Cleanup Disk
  cat >/usr/syno/web/webman/clean_system_disk.cgi <<EOF
#!/bin/sh

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"
if [ -b /dev/md0 ]; then
  mkdir -p /mnt/md0
  mount /dev/md0 /mnt/md0/
  rm -rf /mnt/md0/@autoupdate/*
  rm -rf /mnt/md0/upd@te/*
  rm -rf /mnt/md0/.log.junior/*
  umount /mnt/md0/
  rm -rf /mnt/md0/
  echo '{"success": true}'
else
  echo '{"success": false}'
fi
EOF
  chmod +x /usr/syno/web/webman/clean_system_disk.cgi

  # Create: Reboot to Loader
  cat >/usr/syno/web/webman/reboot_to_loader.cgi <<EOF
#!/bin/sh

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"
if [ -f /usr/bin/loader-reboot.sh ]; then
  /usr/bin/loader-reboot.sh config
  echo '{"success": true}'
else
  echo '{"success": false}'
fi
EOF
  chmod +x /usr/syno/web/webman/reboot_to_loader.cgi

  # Get Boot Logs
  cat >/usr/syno/web/webman/get_logs.cgi <<EOF
#!/bin/sh

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"
echo "==== proc cmdline ===="
cat /proc/cmdline 
echo "==== SynoBoot log ===="
cat /var/log/linuxrc.syno.log
echo "==== Installerlog ===="
cat /tmp/installer_sh.log
echo "==== Messages log ===="
cat /var/log/messages
EOF
  chmod +x /usr/syno/web/webman/get_logs.cgi

  # Error message if bootloader disk is not mounted
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    sed -i 's/c("welcome","desc_install")/"Error: The bootloader disk is not successfully mounted, the installation will fail."/' /usr/syno/web/main.js
  fi

  # Create: Recovery Mode
  cat >/usr/syno/web/webman/recovery.cgi <<EOF
#!/bin/sh

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

echo "Starting ttyd ..."
MSG=""
MSG="\${MSG}Arc Recovery Mode\n"
MSG="\${MSG}\n"
MSG="\${MSG}Using terminal commands to modify system configs, execute external binary\n"
MSG="\${MSG}files, add files, or install unauthorized third-party apps may lead to system\n"
MSG="\${MSG}damages or unexpected behavior, or cause data loss. Make sure you are aware of\n"
MSG="\${MSG}the consequences of each command and proceed at your own risk.\n"
MSG="\${MSG}\n"
MSG="\${MSG}Warning: Data should only be stored in shared folders. Data stored elsewhere\n"
MSG="\${MSG}may be deleted when the system is updated/restarted.\n"
MSG="\${MSG}\n"
MSG="\${MSG}'System partition(/dev/md0) mounted to': /tmpRoot\n"
MSG="\${MSG}To 'Force re-install DSM': http://<ip>:5000/web_install.html\n"
MSG="\${MSG}To 'Reboot to Config Mode': http://<ip>:5000/webman/reboot_to_loader.cgi\n"
MSG="\${MSG}To 'Show Boot Log': http://<ip>:5000/webman/get_logs.cgi\n"
MSG="\${MSG}To 'Reboot Loader' : exec reboot\n"
echo -e "\${MSG}" > /etc/motd

/usr/bin/killall ttyd 2>/dev/null || true
/usr/sbin/ttyd -W -t titleFixed="Arc Recovery" login -f root >/dev/null 2>&1 &

echo "Starting dufs ..."
/usr/bin/killall dufs 2>/dev/null || true
/usr/sbin/dufs -A -p 7304 / >/dev/null 2>&1 &

cp -f /usr/syno/web/web_index.html /usr/syno/web/web_install.html
cp -f /addons/web_index.html /usr/syno/web/web_index.html
mkdir -p /tmpRoot
mount /dev/md0 /tmpRoot
echo "Arc Recovery mode is ready"
EOF
  chmod +x /usr/syno/web/webman/recovery.cgi

  # Start: Recovery Mode
  if [ -n "$(grep force_junior /proc/cmdline 2>/dev/null)" ] && [ -n "$(grep recovery /proc/cmdline 2>/dev/null)" ]; then
    /usr/syno/web/webman/recovery.cgi
  fi

elif [ "${1}" = "patches" ]; then
  # Start getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -oE 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -qw "${TTYN}" && continue
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Starting getty on ${TTYN}"
      if [ -n "${BAUD}" ]; then
        /usr/sbin/getty -L "${TTYN}" "${BAUD}" linux &
      else
        /usr/sbin/getty -L "${TTYN}" linux &
      fi
    fi
  done
  # Set static IP from cmdline
  if grep -q 'network.' /proc/cmdline; then
    for I in $(grep -oE 'network.[0-9a-fA-F:]{12,17}=[^ ]*' /proc/cmdline); do
      MACR="$(echo "${I}" | cut -d. -f2 | cut -d= -f1 | sed 's/://g; s/.*/\L&/' | tr '[:upper:]' '[:lower:]')"
      IPRS="$(echo "${I}" | cut -d= -f2)"
      for ETH in $(ls /sys/class/net/ 2>/dev/null | grep eth); do
        MACX=$(cat /sys/class/net/${ETH}/address 2>/dev/null | sed 's/://g; s/.*/\L&/' | tr '[:upper:]' '[:lower:]')
        if [ "${MACR}" = "${MACX}" ]; then
          echo "Setting IP for ${ETH} to ${IPRS}"
          mkdir -p /etc/sysconfig/network-scripts
          echo "DEVICE=${ETH}" >/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "BOOTPROTO=static" >>/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "ONBOOT=yes" >>/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "IPADDR=$(echo "${IPRS}" | cut -d/ -f1)" >>/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "NETMASK=$(echo "${IPRS}" | cut -d/ -f2)" >>/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "GATEWAY=$(echo "${IPRS}" | cut -d/ -f3)" >>/etc/sysconfig/network-scripts/ifcfg-${ETH}
          echo "${ETH}" >>/etc/ifcfgs
        fi
      done
    done
  fi
elif [ "${1}" = "late" ]; then
  echo "Installing addon misc - ${1}"

  echo "Killing ttyd ..."
  /usr/bin/killall ttyd 2>/dev/null || true

  echo "Killing dufs ..."
  /usr/bin/killall dufs 2>/dev/null || true

  cp -pf /usr/bin/beep /tmpRoot/usr/bin/beep
  cp -pdf /usr/lib/libubsan.so* /tmpRoot/usr/lib/

  mount -t sysfs sysfs /sys
  modprobe acpi-cpufreq
  # CPU Scaling Driver
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf ]; then
    CPUFREQ=$(ls -l /sys/devices/system/cpu/cpufreq/*/* 2>/dev/null | wc -l)
    if [ ${CPUFREQ} -eq 0 ]; then
      echo "CPU does NOT support CPU Performance Scaling, disabling"
      sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
    else
      echo "CPU supports CPU Performance Scaling, enabling"
      sed -i 's/^# acpi-cpufreq/acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
      cp -pf /usr/lib/modules/cpufreq_* /tmpRoot/usr/lib/modules/
    fi
  fi
  modprobe -r acpi-cpufreq
  umount /sys

  # CPU Crypto Support Check
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]; then
    if grep flags /proc/cpuinfo 2>/dev/null | grep -qw sse4_2; then
      echo "CPU Supports SSE4.2, crc32c-intel should load"
    else
      echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"
      sed -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi

    if grep flags /proc/cpuinfo 2>/dev/null | grep -qw aes; then
      echo "CPU Supports AES, aesni-intel should load"
    else
      echo "CPU does NOT support AES, aesni-intel will not load, disabling"
      sed -i 's/support_aesni_intel="yes"/support_aesni_intel="no"/' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf
      sed -i 's/^aesni-intel/# aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # Nvidia GPU Check
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ]; then
    if ! grep -iq 10de /proc/bus/pci/devices 2>/dev/null; then
      echo "NVIDIA GPU is not detected, disabling "
      sed -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
      sed -i 's/^nvidia-uvm/# nvidia-uvm/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
    else
      echo "NVIDIA GPU is detected, nothing to do"
    fi
  fi

  # service
  SERVICE_PATH="/tmpRoot/usr/lib/systemd/system"
  sed -i 's|ExecStart=/|ExecStart=/|g' ${SERVICE_PATH}/syno-oob-check-status.service ${SERVICE_PATH}/SynoInitEth.service ${SERVICE_PATH}/syno_update_disk_logs.service

  # getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -oE 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -qw "${TTYN}" && continue

    mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Make getty\@${TTYN}.service"
      cp -fv /tmpRoot/usr/lib/systemd/system/serial-getty\@.service /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      sed -i "s|^ExecStart=.*|ExecStart=/sbin/agetty %I ${BAUD:-115200} linux|" /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
      ln -vsf /usr/lib/systemd/system/getty\@${TTYN}.service /tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@${TTYN}.service
    fi
  done

  # Open-VM-Tools Fix
  if [ -d /tmpRoot/var/packages/open-vm-tools ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/open-vm-tools/conf/privilege
  fi

  # Qemu-Guest-Agent Fix
  if [ -d /tmpRoot/var/packages/qemu-ga ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/qemu-ga/conf/privilege
  fi

  # Arc Control Fix
  if [ -d /tmpRoot/var/packages/arc-control ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/arc-control/conf/privilege
    chmod u+s /usr/bin/smartctl
    chmod u+s /usr/bin/hdparm
    chmod u+s /usr/sbin/nvme
    chmod u+s /usr/syno/bin/synodisk
  fi

  # SD Card
  [ ! -f /tmpRoot/usr/lib/udev/script/sdcard.sh.bak ] && cp -f /tmpRoot/usr/lib/udev/script/sdcard.sh /tmpRoot/usr/lib/udev/script/sdcard.sh.bak
  echo -en '#!/bin/sh\nexit 0\n' >/tmpRoot/usr/lib/udev/script/sdcard.sh

  # Network Init
  rm -vf /tmpRoot/usr/lib/modules-load.d/70-network*.conf
  mkdir -p /tmpRoot/etc/sysconfig/network-scripts
  mkdir -p /tmpRoot/etc.defaults/sysconfig/network-scripts
  for I in $(ls /etc/sysconfig/network-scripts/ifcfg-eth*); do
    [ ! -f "/tmpRoot/${I}" ] && cp -pf "${I}" "/tmpRoot/${I}"
    [ ! -f "/tmpRoot/${I/etc/etc.defaults}" ] && cp -pf "${I}" "/tmpRoot/${I/etc/etc.defaults}"
  done
  if grep -q 'network.' /proc/cmdline && [ -f "/etc/ifcfgs" ]; then
    for ETH in $(cat /etc/ifcfgs); do
      echo "Copy ifcfg-${ETH}"
      if [ -f "/etc/sysconfig/network-scripts/ifcfg-${ETH}" ]; then
        rm -vf /tmpRoot/etc/sysconfig/network-scripts/ifcfg-* /tmpRoot/etc.defaults/sysconfig/network-scripts/ifcfg-*
        cp -pf /etc/sysconfig/network-scripts/ifcfg-${ETH} /tmpRoot/etc/sysconfig/network-scripts/
        cp -pf /etc/sysconfig/network-scripts/ifcfg-${ETH} /tmpRoot/etc.defaults/sysconfig/network-scripts/
      fi
    done
  fi

  # Community Packages
  if [ ! -f /tmpRoot/usr/syno/etc/packages/feeds ]; then
    mkdir -p /tmpRoot/usr/syno/etc/packages
    echo '[{"feed":"https://spk7.imnks.com","name":"imnks"},{"feed":"https://packages.synocommunity.com","name":"synocommunity"}]' >/tmpRoot/usr/syno/etc/packages/feeds
  fi

  # Copy Loader Reboot
  cp -f /usr/bin/loader-reboot.sh /tmpRoot/usr/bin/loader-reboot.sh
  cp -f /usr/bin/grub-editenv /tmpRoot/usr/bin/grub-editenv
fi
