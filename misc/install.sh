#!/usr/bin/env ash

SED_PATH='/tmpRoot/usr/bin/sed'
XXD_PATH='/tmpRoot/usr/bin/xxd'
LSPCI_PATH='/tmpRoot/usr/bin/lspci'

if [[ ${1} = late ]]; then
  echo "Script for fixing missing HW features dependencies and another functions"

  # Copy utilities to dsm partition
  cp -vf /usr/bin/arpl-reboot.sh /tmpRoot/usr/bin
  cp -vf /usr/bin/arc-reboot.sh /tmpRoot/usr/bin
  cp -vf /usr/bin/grub-editenv /tmpRoot/usr/bin
  cp -vf /usr/bin/i915ids /tmpRoot/usr/bin

  mount -t sysfs sysfs /sys
  modprobe acpi-cpufreq
  # CPU performance scaling
  if [[ -f /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf ]]; then
    CPUFREQ=$(ls -ltr /sys/devices/system/cpu/cpufreq/* 2>/dev/null | wc -l)
    if [[ ${CPUFREQ} = 0 ]]; then
      echo "CPU does NOT support CPU Performance Scaling, disabling"
      ${SED_PATH} -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
    else
      echo "CPU supports CPU Performance Scaling, enabling"
      ${SED_PATH} -i 's/^# acpi-cpufreq/acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
      cp -vf /usr/lib/modules/cpufreq_* /tmpRoot/usr/lib/modules/
    fi
  fi
  umount /sys

  # crc32c-intel
  if [[ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]]; then
    CPUFLAGS=$(</proc/cpuinfo | grep flags | grep sse4_2 | wc -l)
    if [[ ${CPUFLAGS} > 0 ]]; then
      echo "CPU Supports SSE4.2, crc32c-intel should load"
    else
      echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"
      ${SED_PATH} -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # aesni-intel
  if [[ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]]; then
    CPUFLAGS=$(</proc/cpuinfo | grep flags | grep aes | wc -l)
    if [[ ${CPUFLAGS} > 0 ]]; then
      echo "CPU Supports AES, aesni-intel should load"
    else
      echo "CPU does NOT support AES, aesni-intel will not load, disabling"
      ${SED_PATH} -i 's/support_aesni_intel="yes"/support_aesni_intel="no"/' /tmpRoot/etc.defaults/synoinfo.conf
      ${SED_PATH} -i 's/^aesni-intel/# aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # Intel GPU
  if [[ -f /tmpRoot/usr/lib/modules-load.d/70-video-kernel.conf && -f /tmpRoot/usr/lib/modules/i915.ko ]]; then
    export LD_LIBRARY_PATH=/tmpRoot/usr/bin:/tmpRoot/usr/lib:${LD_LIBRARY_PATH}
    GPU="$(${LSPCI_PATH} -n | grep 0300 | grep 8086 | cut -d " " -f 3 | ${SED_PATH} -e 's/://g')"
    echo "${GPU}" >/tmpRoot/root/i915.GPU
    if [[ -n "${GPU}" && $(echo -n "${GPU}" | wc -c) = 8 ]]; then
      if [[ $(grep -i ${GPU} /usr/bin/i915ids | wc -l) = 0 ]]; then
        echo "Intel GPU is not detected (${GPU}), nothing to do"
        #${SED_PATH} -i 's/^i915/# i915/g' /tmpRoot/usr/lib/modules-load.d/70-video-kernel.conf
      else
        GPU_DEF="86800000923e0000"
        GPU_BIN="${GPU:2:2}${GPU:0:2}0000${GPU:6:2}${GPU:4:2}0000"
        KO_SIZE="$(${XXD_PATH} -p /tmpRoot/usr/lib/modules/i915.ko | wc -c)"
        ${XXD_PATH} -c ${KO_SIZE} -p /tmpRoot/usr/lib/modules/i915.ko /tmpRoot/root/i915.ko.hex
        if [[ $(grep -i "${GPU_BIN}" /tmpRoot/root/i915.ko.hex | wc -l) > 0 ]]; then
          echo "Intel GPU is detected (${GPU}), already support"
        else
          echo "Intel GPU is detected (${GPU}), replace id"
          if [[ ! -f /tmpRoot/usr/lib/modules/i915.ko.bak ]]; then
            cp -f /tmpRoot/usr/lib/modules/i915.ko /tmpRoot/usr/lib/modules/i915.ko.bak
          fi
          ${SED_PATH} -i "s/${GPU_DEF}/${GPU_BIN}/; s/308201f706092a86.*70656e6465647e0a//" /tmpRoot/root/i915.ko.hex
          if [[ -n $(</tmpRoot/root/i915.ko.hex) ]]; then
            ${XXD_PATH} -r -p /tmpRoot/root/i915.ko.hex > /tmpRoot/usr/lib/modules/i915.ko
            rm -f /tmpRoot/root/i915.ko.hex
          else
            echo "Intel GPU is detected (${GPU}), replace i915.ko error"
          fi
        fi
      fi
    fi
  fi

  # Nvidia GPU
  if [[ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ]]; then
    NVIDIADEV=$(</proc/bus/pci/devices | grep -i 10de | wc -l)
    if [[ ${NVIDIADEV} = 0 ]]; then
      echo "NVIDIA GPU is not detected, disabling "
      ${SED_PATH} -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
      ${SED_PATH} -i 's/^nvidia-uvm/# nvidia-uvm/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
    else
      echo "NVIDIA GPU is detected, nothing to do"
    fi
  fi
fi