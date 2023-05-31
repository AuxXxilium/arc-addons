#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Force NVMe"
  cp -vf /usr/sbin/nvmeforce.sh /tmpRoot/usr/sbin/nvmeforce.sh
  chmod 755 /tmpRoot/usr/sbin/nvmeforce.sh

  DEST="/tmpRoot/lib/systemd/system/nvmeforce.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Force formate NVMe as Storage"                            >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/nvmeforce.sh"                                     >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/nvmeforce.service /tmpRoot/lib/systemd/system/multi-user.target.wants/nvmeforce.service
fi
