#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/nvmeenable.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec Enable NVMe"
  cp -vf /usr/bin/nvmeenable.sh /tmpRoot/usr/bin/nvmeenable.sh
  cp -vf /usr/bin/bc /tmpRoot/usr/bin/bc
  cp -vf /usr/bin/od /tmpRoot/usr/bin/od
  cp -vf /usr/bin/tr /tmpRoot/usr/bin/tr
  cp -vf /usr/bin/xxd /tmpRoot/usr/bin/xxs
  DEST="/tmpRoot/lib/systemd/system/nvmeenable.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable NVMe as Storage"                                   >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/bin/nvmeenable.sh"                                     >>${DEST}
  echo "ExecStop=/usr/bin/nvmeenable.sh"                                      >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/nvmeenable.service /tmpRoot/lib/systemd/system/multi-user.target.wants/nvmeenable.service
fi
