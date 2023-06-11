#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Enable AME Patch"
  cp -vf /usr/sbin/ame.sh /tmpRoot/usr/sbin/ame.sh

  DEST="/tmpRoot/lib/systemd/system/amepatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable AME Patch"                                         >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/amepatch.sh"                                      >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/amepatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/amepatch.service
fi
