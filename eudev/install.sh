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

  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug
  [ -e /lib/modules/modules.builtin ] || : > /lib/modules/modules.builtin
  [ -d /lib/modules ] && find /lib/modules -type f -name "*.ko" | sort > /lib/modules/modules.order || : > /lib/modules/modules.order
  /usr/sbin/depmod -a || echo "boot depmod skipped"
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }
  echo "Triggering events to udev"
  udevadm trigger --action=add
  udevadm trigger --action=change
  udevadm settle --timeout=30 || echo "udevadm settle failed"
  # Give more time
  sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  /usr/bin/killall udevd
  # modprobe modules for beep, sensors, and virtiofs
  for M in pcspeaker pcspkr coretemp k10temp hwmon-vid it87 nct6683 nct6775 adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90 9p virtiofs dca; do
    /usr/sbin/modprobe "${M}" || true
  done

  for P in tcp sch; do
    for F in $(LC_ALL=C printf '%s\n' /usr/lib/modules/${P}_*.ko | sort -V); do
      [ ! -e "${F}" ] && continue
      /usr/sbin/modprobe "$(basename "${F}" .ko 2>/dev/null)" || true
    done
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
  # Copy firmware files
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  if grep -Eq 'FB@FB|RR@RR' /proc/version 2>/dev/null; then
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/cp -rpf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    else
      echo "Custom Kernel - backup modules."
      /tmpRoot/bin/cp -rpf /usr/lib/modules /tmpRoot/usr/lib/modules.bak
    fi
    /tmpRoot/bin/cp -rpf /usr/lib/modules/* /tmpRoot/usr/lib/modules
    isChange=true
  else
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      echo "Custom Kernel - restore modules from backup."
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/mv -vf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    fi
    for L in $(grep -v '^\s*$\|^\s*#' /addons/modulelist 2>/dev/null | awk '{if (NF == 2) print $1"###"$2}'); do
      O=$(echo "${L}" | awk -F'###' '{print $1}')
      M=$(echo "${L}" | awk -F'###' '{print $2}')
      [ -z "${M}" ] || [ ! -f "/usr/lib/modules/${M}" ] && continue
      if [ "$(echo "${O}" | cut -c1 | sed 's/.*/\U&/')" = "F" ]; then
        /tmpRoot/bin/cp -vrf /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      else
        /tmpRoot/bin/cp -vrn /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      fi
      isChange=true
    done
  fi
  echo "isChange: ${isChange}"
  if [ "${isChange}" = true ]; then
    [ -e /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
    [ -d /tmpRoot/lib/modules ] && find /tmpRoot/lib/modules -type f -name "*.ko" | sort > /tmpRoot/lib/modules/modules.order || : > /tmpRoot/lib/modules/modules.order
    /usr/sbin/depmod -a -b /tmpRoot || echo "dsm depmod skipped"
  fi

  # Restore kvm module
  /usr/sbin/modprobe kvm_intel || true
  /usr/sbin/modprobe kvm_amd || true

  echo "Copy rules"
  /tmpRoot/bin/cp -vrf /usr/lib/udev/* /tmpRoot/usr/lib/udev/

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/udevrules.service"
  {
    echo "[Unit]"
    echo "Description=addon udev daemon"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/udevadm hwdb --update"
    echo "ExecStart=/usr/bin/udevadm control --reload-rules"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/udevrules.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/udevrules.service
fi