#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "early" ]; then
  echo "Installing addon misc - ${1}"

  [ ! -L "/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"
  cp -f "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/2d6520302e39/2d6520312e32/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

elif [ "${1}" = "rcExit" ]; then
  echo "Installing addon misc - ${1}"

  mkdir -p /usr/syno/web/webman
  # clear system disk space
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

  # reboot to loader
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

  # get logs
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

  # error message
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    sed -i 's/c("welcome","desc_install")/"Error: The Bootloader Disk is not successfully mounted! The Installation will fail!!!"/' /usr/syno/web/main.js
  fi

  # recovery.cgi
  cat >/usr/syno/web/webman/recovery.cgi <<EOF
#!/bin/sh

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

echo "Starting ttyd ..."
MSG=""
MSG="\${MSG}Arc Recovery Mode\n"
MSG="\${MSG}To 'Force re-install DSM': http://<ip>:5000/web_install.html\n"
MSG="\${MSG}To 'Reboot to Config Mode': http://<ip>:5000/webman/reboot_to_loader.cgi\n"
MSG="\${MSG}To 'Show Boot Log': http://<ip>:5000/webman/get_logs.cgi\n"
MSG="\${MSG}To 'Reboot Loader' : exec reboot\n"
MSG="\${MSG}To 'Modify system files' : mount /dev/md0\n"
/usr/bin/killall ttyd 2>/dev/null || true
/usr/sbin/ttyd /usr/bin/ash -c "echo -e \"\${MSG}\"; ash" -l >/dev/null 2>&1 &

echo "Starting dufs ..."
/usr/bin/killall dufs 2>/dev/null || true
/usr/sbin/dufs -A -p 7304 / >/dev/null 2>&1 &

cp -f /usr/syno/web/web_index.html /usr/syno/web/web_install.html
cp -f /addons/web_index.html /usr/syno/web/web_index.html
echo "Recovery mode is ready"
EOF
  chmod +x /usr/syno/web/webman/recovery.cgi

  # recovery
  if [ -n "$(grep force_junior /proc/cmdline 2>/dev/null)" ] && [ -n "$(grep recovery /proc/cmdline 2>/dev/null)" ]; then
    /usr/syno/web/webman/recovery.cgi
  fi

elif [ "${1}" = "late" ]; then
  echo "Installing addon misc - ${1}"

  echo "Killing ttyd ..."
  /usr/bin/killall ttyd 2>/dev/null || true

  echo "Killing dufs ..."
  /usr/bin/killall dufs 2>/dev/null || true

  mount -t sysfs sysfs /sys
  modprobe acpi-cpufreq
  # CPU performance scaling
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf ]; then
    CPUFREQ=$(ls -ltr /sys/devices/system/cpu/cpufreq/* 2>/dev/null | wc -l)
    if [ ${CPUFREQ} -eq 0 ]; then
      echo "CPU does NOT support CPU Performance Scaling, disabling"
      sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
    else
      echo "CPU supports CPU Performance Scaling, enabling"
      sed -i 's/^# acpi-cpufreq/acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
      cp -vf /usr/lib/modules/cpufreq_* /tmpRoot/usr/lib/modules/
    fi
  fi
  umount /sys

  # crypto-kernel
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]; then
    # crc32c-intel
    CPUFLAGS=$(cat /proc/cpuinfo 2>/dev/null | grep flags | grep sse4_2 | wc -l)
    if [ ${CPUFLAGS} -gt 0 ]; then
      echo "CPU Supports SSE4.2, crc32c-intel should load"
    else
      echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"
      sed -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi

    # aesni-intel
    CPUFLAGS=$(cat /proc/cpuinfo 2>/dev/null | grep flags | grep aes | wc -l)
    if [ ${CPUFLAGS} -gt 0 ]; then
      echo "CPU Supports AES, aesni-intel should load"
    else
      echo "CPU does NOT support AES, aesni-intel will not load, disabling"
      sed -i 's/support_aesni_intel="yes"/support_aesni_intel="no"/' /tmpRoot/etc.defaults/synoinfo.conf
      sed -i 's/^aesni-intel/# aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # Nvidia GPU
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ]; then
    NVIDIADEV=$(cat /proc/bus/pci/devices 2>/dev/null | grep -i 10de | wc -l)
    if [ ${NVIDIADEV} -eq 0 ]; then
      echo "NVIDIA GPU is not detected, disabling "
      sed -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
      sed -i 's/^nvidia-uvm/# nvidia-uvm/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
    else
      echo "NVIDIA GPU is detected, nothing to do"
    fi
  fi

  # Open-VM-Tools-Fix
  if [ -d /tmpRoot/var/packages/open-vm-tools ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/open-vm-tools/conf/privilege
  fi
  if [ -d /var/packages/open-vm-tools ]; then
    sed -i 's/package/root/g' /var/packages/open-vm-tools/conf/privilege
  fi

  # Qemu-Guest-Agent-Fix
  if [ -d /tmpRoot/var/packages/qemu-ga ]; then
    sed -i 's/package/root/g' /tmpRoot/var/packages/qemu-ga/conf/privilege
  fi
  if [ -d /var/packages/qemu-ga ]; then
    sed -i 's/package/root/g' /var/packages/qemu-ga/conf/privilege
  fi

  # service
  SERVICE_PATH="/tmpRoot/usr/lib/systemd/system"
  sed -i  's|ExecStart=/|ExecStart=-/|g' ${SERVICE_PATH}/syno-oob-check-status.service ${SERVICE_PATH}/SynoInitEth.service

  # sdcard
  cp -f /tmpRoot/usr/lib/udev/script/sdcard.sh /tmpRoot/usr/lib/udev/script/sdcard.sh.bak
  echo -en '#!/bin/sh\nexit 0\n' > /tmpRoot/usr/lib/udev/script/sdcard.sh

  # Network
  rm -vf /tmpRoot/usr/lib/modules-load.d/70-network*.conf
  for I in $(seq 0 7); do
    if [ -f "/etc/sysconfig/network-scripts/ifcfg-eth${I}" ] && [ ! -f "/tmpRoot/etc.defaults/sysconfig/network-scripts/ifcfg-eth${I}" ]; then
      cp -vf "/etc/sysconfig/network-scripts/ifcfg-eth${I}" "/tmpRoot/etc.defaults/sysconfig/network-scripts/ifcfg-eth${I}"
    fi
  done

  # packages
  if [ ! -f /tmpRoot/usr/syno/etc/packages/feeds ]; then
    mkdir -p /tmpRoot/usr/syno/etc/packages
    echo '[{"feed":"https://spk7.imnks.com/","name":"imnks"},{"feed":"https://packages.synocommunity.com","name":"synocommunity"}]' >/tmpRoot/usr/syno/etc/packages/feeds
  fi

  # syslog-ng
  #if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf ]; then
  #  cp -vfp /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf.bak
  #  sed -i 's/destination(d_scemd)/flags(final)/g' /tmpRoot/etc.defaults/syslog-ng/patterndb.d/scemd.conf
  #else
  #  echo "scemd.conf does not exist."
  #fi

  if [ -f /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf ]; then
    cp -vfp /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf.bak
    sed -i 's/destination(d_synosystemd)/flags(final)/g; s/destination(d_systemd)/flags(final)/g' /tmpRoot/etc.defaults/syslog-ng/patterndb.d/synosystemd.conf
  else
    echo "synosystemd.conf does not exist."
  fi

  # copy loader-reboot.sh
  cp -vf /usr/bin/loader-reboot.sh /tmpRoot/usr/bin
  cp -vf /usr/bin/grub-editenv /tmpRoot/usr/bin
fi