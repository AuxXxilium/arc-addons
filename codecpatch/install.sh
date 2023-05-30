#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/codecpatch.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec Codecpatch"
  cp -vf /usr/bin/codecpatch.sh /tmpRoot/usr/bin/codecpatch.sh
  DEST="/tmpRoot/lib/systemd/system/codecpatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Codecpatch"                                        >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/bin/codecpatch.sh"                                     >>${DEST}
  echo "ExecStop=/usr/bin/codecpatch.sh"                                      >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/etc/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/codecpatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service
fi