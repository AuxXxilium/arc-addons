#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  # if [ ! -e /sys/bus/virtio/drivers/virtio_console ]; then
  #   echo virtio_console driver is not loaded, skip to create qemu-ga.service
  #   exit 0
  # fi
  echo "Copying qemu-ga to HD"
  cp -vf /usr/sbin/qemu-ga /tmpRoot/usr/sbin/qemu-ga
  # Create qemu-ga service
  DEST="/tmpRoot/usr/lib/systemd/system/qemu-ga.service"
  echo "[Unit]"                                                                  >${DEST}
  echo "Description=QEMU Guest Agent"                                           >>${DEST}
  echo "After=multi-user.target"                                                >>${DEST}
  echo "IgnoreOnIsolate=true"                                                   >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Service]"                                                              >>${DEST}
  echo "ExecStartPre=/bin/mkdir -p /var/local/run"                              >>${DEST}
  echo "ExecStart=-/usr/sbin/qemu-ga"                                           >>${DEST}
  echo "Restart=always"                                                         >>${DEST}
  echo "RestartSec=10"                                                          >>${DEST}
  echo                                                                          >>${DEST}
  echo "[Install]"                                                              >>${DEST}
  echo "WantedBy=multi-user.target"                                             >>${DEST}

  ln -sf /usr/lib/systemd/system/qemu-ga.service /tmpRoot/etc/systemd/system/multi-user.target.wants/qemu-ga.service
fi
