#!/usr/bin/env ash

# DSM version
MajorVersion=`/bin/get_key_value /etc.defaults/VERSION majorversion`
MinorVersion=`/bin/get_key_value /etc.defaults/VERSION minorversion`
ModuleUnique=`/bin/get_key_value /etc.defaults/VERSION unique` # Avoid confusion with global variables

if [ "${1}" = "modules" ]; then
  echo "Starting eudev daemon - modules"
  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' > /proc/sys/kernel/hotplug
  ln -s /lib/libkmod.so.2.4.0 /lib/libkmod.so.2
  ln -s /usr/bin/udevadm /usr/sbin/udevadm
  /usr/sbin/udevd -d || { echo "FAIL"; exit 1; }
  echo "Triggering add events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=30 || echo "udevadm settle failed"
  # Give more time
  sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  /usr/bin/killall udevd
elif [ "${1}" = "late" ]; then
  echo "Starting eudev daemon - late"  
  # The modules of SA6400 still have compatibility issues, temporarily canceling the copy. TODO: to be resolved
  if [ ! "${ModuleUnique}" = "synology_epyc7002_sa6400" ]; then
    echo "copy modules"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib; /tmpRoot/bin/cp -rnf /usr/lib/modules/* /tmpRoot/usr/lib/modules/
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib; /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
    /usr/sbin/depmod -a -b /tmpRoot/
  fi
  # Copy rules
  cp -vf /etc/udev/rules.d/* /tmpRoot/lib/udev/rules.d/
  DEST="/tmpRoot/lib/systemd/system/udevrules.service"

  echo "[Unit]"                                                                  >${DEST}
  echo "Description=Reload udev rules"                                          >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Service]"                                                              >>${DEST}
  echo "Type=oneshot"                                                           >>${DEST}
  echo "RemainAfterExit=true"                                                   >>${DEST}
  echo "ExecStart=/bin/udevadm hwdb --update"                                   >>${DEST}
  echo "ExecStart=/bin/udevadm control --reload-rules"                          >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Install]"                                                              >>${DEST}
  echo "WantedBy=multi-user.target"                                             >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/udevrules.service /tmpRoot/lib/systemd/system/multi-user.target.wants/udevrules.service
fi
