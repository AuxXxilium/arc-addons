#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec CPU Info"
  cp -vf /usr/sbin/cpuinfo.sh /tmpRoot/usr/sbin/cpuinfo.sh
  chmod 755 /tmpRoot/usr/sbin/cpuinfo.sh

  DEST="/tmpRoot/lib/systemd/system/cpuinfo.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable CPU Info"                                          >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/cpuinfo.sh"                                       >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/cpuinfo.service /tmpRoot/lib/systemd/system/multi-user.target.wants/cpuinfo.service
fi