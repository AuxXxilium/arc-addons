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

  if [ -f "/usr/lib/modules/update/i915.ko" ] && lspci -nd ::300 2>/dev/null | grep -Eq '8086:[0-9a-fA-F]{4}'; then
    GPU="$(lspci -nd ::300 2>/dev/null | grep -Eo '8086:[0-9a-fA-F]{4}' | head -n1 | sed 's/://')"
    PCI="pci:v0000$(echo "${GPU:-}" | cut -c1-4)d0000$(echo "${GPU:-}" | cut -c5-8)"
    if modinfo -F alias "/usr/lib/modules/i915.ko" 2>/dev/null | grep -iq "${PCI}"; then
      echo "base i915.ko supports ${GPU}"
      rm -rf /usr/lib/modules/update 2>/dev/null || true
    else
      if modinfo -F alias "/usr/lib/modules/update/i915.ko" 2>/dev/null | grep -iq "${PCI}"; then
        echo "update i915.ko supports ${GPU}"
        mv -vf /usr/lib/modules/update/* /usr/lib/modules/ 2>/dev/null
      else
        echo "No i915.ko supports ${GPU}"
        rm -rf /usr/lib/modules/update 2>/dev/null || true
      fi
    fi
  else
    rm -rf /usr/lib/modules/update 2>/dev/null || true
  fi

  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug

  mkdir -p /run/udev
  /usr/sbin/depmod -a || echo "boot depmod skipped"
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }
  echo "Triggering events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm settle --timeout=30 || echo "udevadm settle after add failed"
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=30 || echo "udevadm settle after change failed"
  sleep 10
  udevadm control --stop 2>/dev/null || /usr/bin/killall udevd 2>/dev/null || true
  # Wait for udevd to fully exit before DSM boots its own udev
  for _i in $(seq 1 5); do
    pkill -0 -x udevd 2>/dev/null || break
    sleep 1
  done
  /usr/bin/killall -9 udevd 2>/dev/null || true
  rm -rf /run/udev
  # modprobe modules for beep, sensors, and virtiofs
  for M in pcspeaker pcspkr coretemp k10temp hwmon-vid it87 nct6683 nct6775 adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90 9p virtiofs; do
    /usr/sbin/modprobe "${M}" 2>/dev/null || true
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
  # read config
  PLATFORM=$(awk -F'"' '/^export PLATFORM=/ {print $2}' "/addons/addons.sh")
  PRODUCTVER=$(awk -F'"' '/^export PRODUCTVER=/ {print $2}' "/addons/addons.sh")
  # Copy firmware files
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  MODVER="/tmpRoot/usr/lib/modules.${PLATFORM}-${PRODUCTVER}"
  MODDIR="/tmpRoot/usr/lib/modules"
  if grep -q 'RR@RR' /proc/version 2>/dev/null; then
    KERNEL="Custom"
  else
    KERNEL="Official"
  fi

  if [ ! -d "${MODVER}" ]; then
    echo "${KERNEL} Kernel - backup existing modules."
    rm -rf /tmpRoot/usr/lib/modules.* 2>/dev/null || true
    /tmpRoot/bin/cp -rpf "${MODDIR}" "${MODVER}" 2>/dev/null || true
  else
    echo "${KERNEL} Kernel - restore modules from backup."
    /tmpRoot/bin/rm -rf "${MODDIR}" 2>/dev/null || true
    /tmpRoot/bin/mv -f "${MODVER}" "${MODDIR}" 2>/dev/null || true
  fi

  # Remove stale module backups that don't match current platform-productver
  for OLD in /tmpRoot/usr/lib/modules.*; do
    [ "${OLD}" = "${MODVER}" ] && continue
    echo "Removing stale module backup: ${OLD}"
    /tmpRoot/bin/rm -rf "${OLD}" 2>/dev/null || true
  done

  if [ "${KERNEL}" = "Custom" ]; then
    /tmpRoot/bin/cp -rpf /usr/lib/modules/* "${MODDIR}" 2>/dev/null || true
    isChange=true
  else
    for L in $(grep -v '^\s*$\|^\s*#' /addons/modulelist 2>/dev/null | awk 'NF==2 {print $1"###"$2}'); do
      O="${L%%###*}"
      M="${L##*###}"
      [ -z "${M}" ] || [ ! -f "/usr/lib/modules/${M}" ] && continue
      case "${O}" in
        [Ff]*) /tmpRoot/bin/cp -vrf "/usr/lib/modules/${M}" "${MODDIR}/" 2>/dev/null || true ;;
        *)     /tmpRoot/bin/cp -vrn "/usr/lib/modules/${M}" "${MODDIR}/" 2>/dev/null || true ;;
      esac
      isChange=true
    done
  fi
  echo "isChange: ${isChange}"
  if [ "${isChange}" = true ]; then
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