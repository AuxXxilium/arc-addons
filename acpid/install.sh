#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for ACPI button"
  mkdir -p /tmpRoot/etc/acpi/events/
  cp -vf /etc/acpi/events/power /tmpRoot/etc/acpi/events/power
  cp -vf /usr/sbin/acpid /tmpRoot/usr/sbin/acpid
  cp -vf /etc/acpi/power.sh /tmpRoot/etc/acpi/power.sh

  DEST=/tmpRoot/lib/systemd/system/acpid.service
  echo "[Unit]"                                  >${DEST}
  echo "Description=ACPI Daemon"                >>${DEST}
  echo "DefaultDependencies=no"                 >>${DEST}
  echo "IgnoreOnIsolate=true"                   >>${DEST}
  echo "After=multi-user.target"                >>${DEST}
  echo                                          >>${DEST}
  echo "[Service]"                              >>${DEST}
  echo "Restart=always"                         >>${DEST}
  echo "RestartSec=30"                          >>${DEST}
  echo "ExecStartPre=/usr/sbin/modprobe button" >>${DEST}
  echo "ExecStart=/usr/sbin/acpid -f"           >>${DEST}
  echo                                          >>${DEST}
  echo "[X-Synology]"                           >>${DEST}
  echo "Author=Virtualization Team"             >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/acpid.service /tmpRoot/lib/systemd/system/multi-user.target.wants/acpid.service
fi