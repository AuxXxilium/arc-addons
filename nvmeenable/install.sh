#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Enable NVMe"
  cp -vf /usr/sbin/nvmeenable.sh /tmpRoot/usr/sbin/nvmeenable.sh
  cp -vf /usr/sbin/bc /tmpRoot/usr/sbin/bc
  cp -vf /usr/sbin/od /tmpRoot/usr/sbin/od
  cp -vf /usr/sbin/tr /tmpRoot/usr/sbin/tr
  cp -vf /usr/sbin/xxd /tmpRoot/usr/sbin/xxs
  chmod 755 /tmpRoot/usr/sbin/bc
  chmod 755 /tmpRoot/usr/sbin/od
  chmod 755 /tmpRoot/usr/sbin/tr
  chmod 755 /tmpRoot/usr/sbin/xxs

  DEST="/tmpRoot/lib/systemd/system/nvmeenable.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable NVMe as Storage"                                   >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/nvmeenable.sh"                                    >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/nvmeenable.service /tmpRoot/lib/systemd/system/multi-user.target.wants/nvmeenable.service
fi
