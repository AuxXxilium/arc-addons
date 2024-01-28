#!/usr/bin/env ash

# DSM version
MajorVersion=$(/bin/get_key_value /etc.defaults/VERSION majorversion)
MinorVersion=$(/bin/get_key_value /etc.defaults/VERSION minorversion)
ModuleUnique=$(/bin/get_key_value /etc.defaults/VERSION unique) # Avoid confusion with global variables

echo "eudev: MajorVersion:${MajorVersion} MinorVersion:${MinorVersion}"

if [ "${1}" = "modules" ]; then
  echo "Starting eudev daemon - modules"
  if [ "${MinorVersion}" -lt "2" ]; then # < 2
    tar zxf /addons/eudev-7.1.tgz -C /
  else
    tar zxf /addons/eudev-7.2.tgz -C /
  fi
  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug
  chmod 755 /usr/sbin/udevd /usr/bin/kmod /usr/bin/udevadm /usr/lib/udev/*
  /usr/sbin/depmod -a
  /usr/sbin/udevd -d || {
    echo "eudev: FAILED"
    exit 1
  }
  echo "eudev: Triggering add events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=30 || echo "eudev: udevadm settle failed"
  # Give more time
  sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  /usr/bin/killall udevd
elif [ "${1}" = "late" ]; then
  echo "Starting eudev daemon - late"
  echo "eudev: ${ModuleUnique}"

  echo "eudev: copy Modules and Firmware"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  /tmpRoot/bin/cp -vrf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  /tmpRoot/bin/cp -vrf /usr/lib/modules/* /tmpRoot/usr/lib/modules/
  /usr/sbin/depmod -a -b /tmpRoot/

  echo "eudev: copy Rules"
  cp -vf /usr/lib/udev/rules.d/* /tmpRoot/usr/lib/udev/rules.d/
  echo "eudev: copy HWDB"
  mkdir -p /tmpRoot/etc/udev/hwdb.d
  cp -vf /etc/udev/hwdb.d/* /tmpRoot/etc/udev/hwdb.d/

  DEST="/tmpRoot/lib/systemd/system/udevrules.service"
  echo "[Unit]"                                                                  >${DEST}
  echo "Description=Reload udev Rules"                                          >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Service]"                                                              >>${DEST}
  echo "Type=oneshot"                                                           >>${DEST}
  echo "RemainAfterExit=true"                                                   >>${DEST}
  echo "ExecStart=/usr/bin/udevadm hwdb --update"                               >>${DEST}
  echo "ExecStart=/usr/bin/udevadm control --reload-rules"                      >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Install]"                                                              >>${DEST}
  echo "WantedBy=multi-user.target"                                             >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/udevrules.service /tmpRoot/lib/systemd/system/multi-user.target.wants/udevrules.service
fi