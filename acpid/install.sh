#!/usr/bin/env ash

#if [ "${1}" = "early" ]; then
  #/usr/sbin/acpid
#el
if [ "${1}" = "late" ]; then
  #/usr/bin/killall acpid
  echo "Installing daemon for ACPI button"
  cp -vf /usr/sbin/acpid /tmpRoot/usr/sbin/acpid
  mkdir -p /tmpRoot/etc/acpi/events/
  cp -vf /etc/acpi/events/power /tmpRoot/etc/acpi/events/power
  cp -vf /etc/acpi/power.sh /tmpRoot/etc/acpi/power.sh
  DEST="/tmpRoot/lib/systemd/system/acpid.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=ACPI Daemon"                                              >>${DEST}
  echo "DefaultDependencies=no"                                               >>${DEST}
  echo "IgnoreOnIsolate=true"                                                 >>${DEST}
  echo "After=multi-user.target"                                              >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Restart=always"                                                       >>${DEST}
  echo "RestartSec=30"                                                        >>${DEST}
  echo "PIDFile=/var/run/acpid.pid"                                           >>${DEST}
  echo "ExecStart=/usr/sbin/acpid -f"                                         >>${DEST}
  echo                                                                        >>${DEST}
  echo "[X-Synology]"                                                         >>${DEST}
  echo "Author=Virtualization Team"                                           >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/etc/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/acpid.service /tmpRoot/lib/systemd/system/multi-user.target.wants/acpid.service
fi
