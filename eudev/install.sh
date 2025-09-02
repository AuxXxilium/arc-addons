#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "early" ]; then
  echo "Installing addon eudev - ${1}"
  tar -zxf /addons/eudev-7.1.tgz -C /
  [ ! -L "/usr/sbin/modprobe" ] && ln -vsf /usr/bin/kmod /usr/sbin/modprobe
  [ ! -L "/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  [ ! -L "/usr/sbin/depmod" ] && ln -vsf /usr/bin/kmod /usr/sbin/depmod

elif [ "${1}" = "modules" ]; then
  echo "Installing addon eudev - ${1}"

  # mv -f /usr/lib/udev/rules.d/60-persistent-storage.rules /usr/lib/udev/rules.d/60-persistent-storage.rules.bak
  # mv -f /usr/lib/udev/rules.d/60-persistent-storage-tape.rules /usr/lib/udev/rules.d/60-persistent-storage-tape.rules.bak
  # mv -f /usr/lib/udev/rules.d/80-net-name-slot.rules /usr/lib/udev/rules.d/80-net-name-slot.rules.bak
  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug
  /usr/sbin/depmod -a
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }
  echo "Triggering add events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=30 || echo "udevadm settle failed"
  # Give more time
  sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  /usr/bin/killall udevd
  # modprobe modules for the beep
  /usr/sbin/modprobe pcspeaker || true
  /usr/sbin/modprobe pcspkr || true
  # modprobe modules for the sensors
  for I in drivetemp coretemp k10temp hwmon-vid it87 nct6683 nct6775 adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90; do
    /usr/sbin/modprobe "${I}" || true
  done

  # Remove kvm module
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_intel && /usr/sbin/modprobe -r kvm_intel || true # kvm-intel.ko
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_amd && /usr/sbin/modprobe -r kvm_amd || true     # kvm-amd.ko

elif [ "${1}" = "late" ]; then
  echo "Installing addon eudev - ${1}"
  # [ ! -L "/tmpRoot/usr/sbin/modprobe" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modprobe
  [ ! -L "/tmpRoot/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modinfo
  [ ! -L "/tmpRoot/usr/sbin/depmod" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/depmod

  [ ! -f "/tmpRoot/usr/bin/eject" ] && cp -vpf /usr/bin/eject /tmpRoot/usr/bin/eject

  echo "copy modules"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  isChange=false
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  if grep -q 'RR@RR' /proc/version 2>/dev/null; then
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/cp -rpf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    else
      echo "Custom Kernel - backup modules."
      /tmpRoot/bin/cp -rpf /tmpRoot/usr/lib/modules /tmpRoot/usr/lib/modules.bak
    fi
    /tmpRoot/bin/cp -rpf /usr/lib/modules/* /tmpRoot/usr/lib/modules
    isChange=true
  else
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      echo "Custom Kernel Restore - restore modules from backup."
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/mv -rf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    fi
    for L in $(grep -v '^\s*$\|^\s*#' /addons/modulelist 2>/dev/null | awk '{if (NF == 2) print $1"###"$2}'); do
      O=$(echo "${L}" | awk -F'###' '{print $1}')
      M=$(echo "${L}" | awk -F'###' '{print $2}')
      [ -z "${M}" ] || [ ! -f "/usr/lib/modules/${M}" ] && continue
      if [ "$(echo "${O:0:1}" | sed 's/.*/\U&/')" = "F" ]; then
        /tmpRoot/bin/cp -vrf /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      else
        /tmpRoot/bin/cp -vrn /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      fi
      isChange=true
    done
  fi
  echo "isChange: ${isChange}"
  [ "${isChange}" = "true" ] && /usr/sbin/depmod -a -b /tmpRoot

  # Restore kvm module
  /usr/sbin/modprobe kvm_intel || true # kvm-intel.ko
  /usr/sbin/modprobe kvm_amd || true   # kvm-amd.ko

  echo "Copy rules"
  /tmpRoot/bin/cp -vrf /usr/lib/udev/* /tmpRoot/usr/lib/udev/

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  {
    echo "[Unit]"
    echo "Description=RR addon udev daemon"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/udevadm hwdb --update"
    echo "ExecStart=/usr/bin/udevadm control --reload-rules"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"/tmpRoot/usr/lib/systemd/system/udevrules.service"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/udevrules.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/udevrules.service
fi