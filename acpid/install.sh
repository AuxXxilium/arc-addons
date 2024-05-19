#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon acpid - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/etc/acpi/events/
  # [ ! -f /tmpRoot/etc/acpi/events/power.bak -a -f /tmpRoot/etc/acpi/events/power ] && cp -vf /tmpRoot/etc/acpi/events/power /tmpRoot/etc/acpi/events/power.bak
  # [ ! -f /tmpRoot/etc/acpi/power.sh.bak -a -f /tmpRoot/etc/acpi/power.sh ] && cp -vf /tmpRoot/etc/acpi/power.sh /tmpRoot/etc/acpi/power.sh.bak
  # [ ! -f /tmpRoot/usr/sbin/acpid.bak -a -f /tmpRoot/usr/sbin/acpid ] && cp -vf /tmpRoot/usr/sbin/acpid /tmpRoot/usr/sbin/acpid.bak
  cp -vf /etc/acpi/events/power /tmpRoot/etc/acpi/events/power
  cp -vf /etc/acpi/power.sh /tmpRoot/etc/acpi/power.sh
  cp -vf /usr/sbin/acpid /tmpRoot/usr/sbin/acpid
  if [ -f /usr/lib/modules/button.ko ]; then
    cp -vf /usr/lib/modules/button.ko /tmpRoot/usr/lib/modules/button.ko
  else
    echo "No button.ko found"
  fi

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/acpid.service"
  echo "[Unit]"                                               >${DEST}
  echo "Description=addon acpid"                             >>${DEST}
  echo "DefaultDependencies=no"                              >>${DEST}
  echo "IgnoreOnIsolate=true"                                >>${DEST}
  echo "After=multi-user.target"                             >>${DEST}
  echo                                                       >>${DEST}
  echo "[Service]"                                           >>${DEST}
  echo "Restart=always"                                      >>${DEST}
  echo "RestartSec=30"                                       >>${DEST}
  echo "ExecStartPre=-/usr/sbin/modprobe button"             >>${DEST}
  echo "ExecStart=/usr/sbin/acpid -f"                        >>${DEST}
  echo "ExecStopPost=-/usr/sbin/modprobe -r button"          >>${DEST}
  echo                                                       >>${DEST}
  echo "[X-Synology]"                                        >>${DEST}
  echo "Author=Virtualization Team"                          >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/acpid.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon acpid - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -f /tmpRoot/etc/acpi/events/power
  rm -f /tmpRoot/etc/acpi/power.sh
  rm -f /tmpRoot/usr/sbin/acpid
  # [ -f /tmpRoot/etc/acpi/events/power.bak ] && mv -vf /tmpRoot/etc/acpi/events/power.bak /tmpRoot/etc/acpi/events/power
  # [ -f /tmpRoot/etc/acpi/power.sh.bak ] && mv -vf /tmpRoot/etc/acpi/power.sh.bak /tmpRoot/etc/acpi/power.sh
  # [ -f /tmpRoot/usr/sbin/acpid.bak ] && mv -vf /tmpRoot/usr/sbin/acpid.bak /tmpRoot/usr/sbin/acpid
fi