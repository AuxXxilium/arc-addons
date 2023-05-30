#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/nvmeforce.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec Force NVMe"
  cp -vf /usr/bin/nvmeforce.sh /tmpRoot/usr/bin/nvmeforce.sh
  DEST="/tmpRoot/lib/systemd/system/nvmeforce.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Force formate NVMe as Storage"                            >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/bin/nvmeforce.sh"                                      >>${DEST}
  echo "ExecStop=/usr/bin/nvmeforce.sh"                                       >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/nvmeforce.service /tmpRoot/lib/systemd/system/multi-user.target.wants/nvmeforce.service
fi
