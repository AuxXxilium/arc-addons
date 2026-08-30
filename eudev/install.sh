#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "early" ]; then
  echo "Installing addon eudev - ${1}"

  EUDEVPKG="$(ls /addons/eudev-*-*.tgz 2>/dev/null | head -n1)"
  if [ -z "${EUDEVPKG}" ]; then
    echo "ERROR: no eudev-*.tgz found in /addons/"
    exit 1
  fi
  tar -zxf "${EUDEVPKG}" -C /
  [ -L "/usr/sbin/modprobe" ] || ln -vsf /usr/bin/kmod /usr/sbin/modprobe
  [ -L "/usr/sbin/modinfo" ] || ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  [ -L "/usr/sbin/depmod" ] || ln -vsf /usr/bin/kmod /usr/sbin/depmod
  exit 0

elif [ "${1}" = "modules" ]; then
  echo "Installing addon eudev - ${1}"

  # Match the whole PCI display class (03), not just subclass 0300 "VGA compatible
  # controller". Modern Intel iGPUs report 0380 "Display controller" instead - a Raptor
  # Lake-S UHD (8086:a782) shows up as class 0380 - and some report 0302.
  GPU="$(lspci -n 2>/dev/null | grep -E ' 03[0-9a-fA-F]{2}: 8086:[0-9a-fA-F]{4}' \
    | grep -Eo '8086:[0-9a-fA-F]{4}' | head -n1 | sed 's/://')"
  AMDGPU="$(lspci -n 2>/dev/null | grep -E ' 03[0-9a-fA-F]{2}: 1002:[0-9a-fA-F]{4}' \
    | grep -Eo '1002:[0-9a-fA-F]{4}' | head -n1 | sed 's/://')"
  # Two module-set layouts are in the field and both have to work here:
  #
  #   split - i915 and its DRM stack live in /usr/lib/modules/update, shadowing
  #           the kernel's own 5.10 drm/ttm/drm_kms_helper by the same names.
  #           depmod treats update/ as higher priority on its own, so leaving
  #           the directory in place silently installs the backport whether or
  #           not it fits this GPU. The directory therefore has to be either
  #           moved down into the module root or deleted outright.
  #   flat  - a single set with i915.ko at the module root and no update/ at
  #           all, because the colliding 5.10 DRM modules are not built. Here
  #           nothing shadows anything and the only question is whether i915
  #           is wanted; if not, the stack is removed by name.
  #
  # The core is shared: i915 and amdgpu are both built against it, so it is only
  # dead weight when neither vendor's GPU is present. Each vendor driver goes
  # when its own GPU is absent.
  DRM_CORE="drm drm_kms_helper drm_display_helper drm_buddy drm_mipi_dsi ttm dmabuf \
            drm_ttm_helper drm_suballoc_helper drm_panel_orientation_quirks gpu-sched"
  I915_ONLY="i915 i915-compat intel-gtt"
  AMD_ONLY="amdgpu amdxcp"
  if [ -f "/usr/lib/modules/update/i915.ko" ]; then
    I915KO="/usr/lib/modules/update/i915.ko"
  elif [ -f "/usr/lib/modules/i915.ko" ]; then
    I915KO="/usr/lib/modules/i915.ko"
  else
    I915KO=""
  fi

  if [ -f "/usr/lib/modules/update/amdgpu.ko" ]; then
    AMDKO="/usr/lib/modules/update/amdgpu.ko"
  elif [ -f "/usr/lib/modules/amdgpu.ko" ]; then
    AMDKO="/usr/lib/modules/amdgpu.ko"
  else
    AMDKO=""
  fi

  I915_WANTED=false
  if [ -n "${I915KO}" ] && [ -n "${GPU}" ]; then
    PCI="pci:v0000$(echo "${GPU}" | cut -c1-4)d0000$(echo "${GPU}" | cut -c5-8)"
    if modinfo -F alias "${I915KO}" 2>/dev/null | grep -iq "${PCI}"; then
      I915_WANTED=true
      echo "eudev: i915 supports ${GPU}, keeping it"
    else
      echo "eudev: i915 does not support ${GPU}, removing it"
    fi
  elif [ -n "${I915KO}" ]; then
    echo "eudev: no Intel GPU present, removing i915"
  fi

  # Matched by vendor rather than by alias: amdgpu binds every 1002 display device
  # through a PCI_ANY_ID catch-all, so an alias lookup would reject supported
  # hardware the ID table never names individually.
  AMD_WANTED=false
  if [ -n "${AMDKO}" ] && [ -n "${AMDGPU}" ]; then
    AMD_WANTED=true
    echo "eudev: AMD GPU ${AMDGPU} present, keeping amdgpu"
  elif [ -n "${AMDKO}" ]; then
    echo "eudev: no AMD GPU present, removing amdgpu"
  fi

  if [ -n "${I915KO}" ] || [ -n "${AMDKO}" ]; then
    if [ "${I915_WANTED}" = true ] || [ "${AMD_WANTED}" = true ]; then
      # On a split set the backport has to come down to the module root, where
      # it replaces the 5.10 modules of the same name - the whole point of the
      # shadowing. On a flat set there is nothing to move and the mv is a no-op.
      [ -d /usr/lib/modules/update ] && mv -f /usr/lib/modules/update/* /usr/lib/modules/ 2>/dev/null
      [ "${I915_WANTED}" = true ] || for M in ${I915_ONLY}; do
        rm -f "/usr/lib/modules/${M}.ko" 2>/dev/null || true
      done
      [ "${AMD_WANTED}" = true ] || for M in ${AMD_ONLY}; do
        rm -f "/usr/lib/modules/${M}.ko" 2>/dev/null || true
      done
    else
      for M in ${I915_ONLY} ${AMD_ONLY} ${DRM_CORE}; do
        rm -f "/usr/lib/modules/${M}.ko" 2>/dev/null || true
      done
    fi
  fi
  # Nothing below may see update/ any more: it is either merged, or its content
  # is unwanted. Anything else left in there would still outrank the base set at
  # depmod time without ever appearing in modules.order.
  rm -rf /usr/lib/modules/update 2>/dev/null || true

  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug

  rm -f /usr/lib/modules/pgdrv.ko 2>/dev/null || true

  [ -e /usr/lib/modules/modules.builtin ] || : > /usr/lib/modules/modules.builtin

  # The prune of ./update is belt and braces: the GPU check above already
  # merged or deleted the directory, so on both layouts -path ./update should
  # no longer match anything by the time we get here.
  if [ -d /usr/lib/modules ]; then
    (cd /usr/lib/modules && find . -path ./update -prune -o -type f -name "*.ko" -print \
      | sed 's|^\./||' | sort) > /usr/lib/modules/modules.order
  else
    : > /usr/lib/modules/modules.order
  fi

  /usr/sbin/depmod -a || echo "boot depmod skipped"
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }
  echo "Triggering events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=60 || echo "udevadm settle after 60s failed"
  /usr/bin/killall udevd 2>/dev/null || true

  /usr/sbin/modprobe pcspeaker || true
  /usr/sbin/modprobe pcspkr || true

  /usr/sbin/modprobe sg || true

  for I in coretemp k10temp hwmon-vid; do
    /usr/sbin/modprobe "${I}" || true
  done

  MEV="$(sed -n 's/.*\bmev=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)"
  if [ "${MEV}" = "physical" ] || [ -z "${MEV}" ]; then
    for I in wmi it87 nct6683 nct6775 nct7802 f71805f f71882fg f75375s dme1737 \
             w83627ehf w83627hf w83781d w83791d w83792d w83793 w83795 asc7621 \
             adt7462 adt7470 adt7475 adm1021 adm1025 adm1026 adm1031 adm9240 \
             lm63 lm75 lm77 lm78 lm80 lm85 lm90 lm95245 max6639 \
             drivetemp asus_atk0110; do
      /usr/sbin/modprobe "${I}" || true
    done
  else
    /usr/sbin/modprobe 9p || true
    /usr/sbin/modprobe virtiofs || true
  fi

  for P in tcp sch; do
    for F in $(LC_ALL=C printf '%s\n' /usr/lib/modules/${P}_*.ko | sort -V); do
      [ ! -e "${F}" ] && continue
      /usr/sbin/modprobe "$(basename "${F}" .ko 2>/dev/null)" || true
    done
  done

  for D in /sys/bus/*/devices/*/modalias /sys/devices/*/modalias; do
    [ -r "${D}" ] && cat "${D}"
  done 2>/dev/null | sort -u | while read -r A; do
    [ -n "${A}" ] || continue
    /usr/sbin/modprobe "${A}" 2>/dev/null && echo "eudev: loaded driver for ${A}" || true
  done

  # Remove kvm module
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_intel && /usr/sbin/modprobe -r kvm_intel || true # kvm-intel.ko
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_amd && /usr/sbin/modprobe -r kvm_amd || true     # kvm-amd.ko

elif [ "${1}" = "late" ]; then
  echo "Installing addon eudev - ${1}"
  [ ! -L "/tmpRoot/usr/sbin/modprobe" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modprobe
  [ ! -L "/tmpRoot/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modinfo
  [ ! -L "/tmpRoot/usr/sbin/depmod" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/depmod
  [ ! -f "/tmpRoot/usr/bin/eject" ] && cp -vpf /usr/bin/eject /tmpRoot/usr/bin/eject

  echo "copy modules"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  isChange=false
  SKIPOVERLAY=false
  # Copy firmware files
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  MODBAK="/tmpRoot/usr/lib/modules.${PLATFORM}-${PRODUCTVER}.tgz"
  MODDIR="/tmpRoot/usr/lib/modules"

  # Remove stale backups from other platform/productver combos (old dirs and old tgz alike)
  for STALE in /tmpRoot/usr/lib/modules.*; do
    [ -e "${STALE}" ] || continue
    [ "${STALE}" = "${MODBAK}" ] && continue
    /tmpRoot/bin/rm -rf "${STALE}" 2>/dev/null || true
  done

  if grep -q 'AuxXxilium@Xpenology' /proc/version 2>/dev/null; then
    if [ -f "${MODBAK}" ] && tar -tzf "${MODBAK}" >/dev/null 2>&1; then
      echo "Custom Kernel - restore stock modules from backup."
      /tmpRoot/bin/rm -rf "${MODDIR}" 2>/dev/null || true
      mkdir -p "${MODDIR}"
      tar -zxf "${MODBAK}" -C "${MODDIR}" 2>/dev/null || true
    else
      # A backup that exists but does not list is truncated or corrupt - drop it and take a
      # fresh one. Restoring from it would wipe MODDIR and leave nothing bootable behind.
      [ -f "${MODBAK}" ] && echo "Custom Kernel - backup is unreadable, discarding it."
      /tmpRoot/bin/rm -f "${MODBAK}" 2>/dev/null || true
      echo "Custom Kernel - backup stock modules."
      if ! tar -zcf "${MODBAK}" -C "${MODDIR}" . 2>/dev/null || ! tar -tzf "${MODBAK}" >/dev/null 2>&1; then
        # Without a good backup the overlay below is a one-way trip: the official-kernel boot
        # would have nothing to restore and would keep running custom modules. Skip it.
        echo "eudev: WARNING - module backup failed, skipping custom module overlay."
        /tmpRoot/bin/rm -f "${MODBAK}" 2>/dev/null || true
        isChange=false
        SKIPOVERLAY=true
      fi
    fi
    if [ "${SKIPOVERLAY}" != true ]; then
      /tmpRoot/bin/cp -rpf /usr/lib/modules/* "${MODDIR}" 2>/dev/null || true
      isChange=true
    fi
  else
    if [ -f "${MODBAK}" ] && tar -tzf "${MODBAK}" >/dev/null 2>&1; then
      echo "Official Kernel - restore modules from backup."
      /tmpRoot/bin/rm -rf "${MODDIR}" 2>/dev/null || true
      mkdir -p "${MODDIR}"
      tar -zxf "${MODBAK}" -C "${MODDIR}" 2>/dev/null || true
      /tmpRoot/bin/rm -f "${MODBAK}" 2>/dev/null || true
    elif [ -f "${MODBAK}" ]; then
      # Corrupt backup: leave MODDIR alone. It still holds the custom modules from the last
      # boot, which is wrong but bootable - wiping it for a failed extract would not be.
      echo "eudev: WARNING - module backup is unreadable, keeping modules as-is."
      /tmpRoot/bin/rm -f "${MODBAK}" 2>/dev/null || true
    fi
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

  if [ -f "${MODDIR}/pgdrv.ko" ]; then
    echo "eudev: Removing pgdrv.ko (Realtek PG tool) - conflicts with the r81xx NIC drivers"
    /tmpRoot/bin/rm -f "${MODDIR}/pgdrv.ko" 2>/dev/null || true
    isChange=true
  fi

  if [ -f /usr/lib/modules/sg.ko ] && [ ! -f "${MODDIR}/sg.ko" ]; then
    echo "eudev: Adding sg.ko (SCSI generic - needed by IronWolf Health Management)"
    /tmpRoot/bin/cp -vpf /usr/lib/modules/sg.ko "${MODDIR}/" 2>/dev/null || true
    isChange=true
  fi

  echo "isChange: ${isChange}"
  if [ "${isChange}" = true ]; then
    [ -f /usr/lib/modules/modules.builtin ] && cp -f /usr/lib/modules/modules.builtin /tmpRoot/usr/lib/modules/modules.builtin
    [ -f /usr/lib/modules/modules.order ] && cp -f /usr/lib/modules/modules.order /tmpRoot/usr/lib/modules/modules.order
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