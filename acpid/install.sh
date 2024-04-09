#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon acpid - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/etc/acpi/events/
  cp -vf /etc/acpi/events/power /tmpRoot/etc/acpi/events/power
  cp -vf /etc/acpi/power.sh /tmpRoot/etc/acpi/power.sh
  cp -vf /usr/sbin/acpid /tmpRoot/usr/sbin/acpid
  cp -vf /usr/lib/modules/button.ko /tmpRoot/usr/lib/modules/button.ko

  DEST="/tmpRoot/lib/systemd/system/acpid.service"
  echo "[Unit]"                                        >${DEST}
  echo "Description=addon acpid"                      >>${DEST}
  echo "DefaultDependencies=no"                       >>${DEST}
  echo "IgnoreOnIsolate=true"                         >>${DEST}
  echo "After=multi-user.target"                      >>${DEST}
  echo                                                >>${DEST}
  echo "[Service]"                                    >>${DEST}
  echo "Restart=always"                               >>${DEST}
  echo "RestartSec=30"                                >>${DEST}
  echo "ExecStartPre=-/usr/sbin/modprobe button"      >>${DEST}
  echo "ExecStart=/usr/sbin/acpid -f"                 >>${DEST}
  echo "ExecStopPost=-/usr/sbin/modprobe -r button"   >>${DEST}
  echo                                                >>${DEST}
  echo "[X-Synology]"                                 >>${DEST}
  echo "Author=Virtualization Team"                   >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/acpid.service /tmpRoot/lib/systemd/system/multi-user.target.wants/acpid.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon acpid - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -f /tmpRoot/etc/acpi/events/power
  rm -f /tmpRoot/etc/acpi/power.sh
  rm -f /tmpRoot/usr/sbin/acpid
fi
