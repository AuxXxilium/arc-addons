#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/deduplication.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec Deduplication"
  cp -vf /usr/bin/diskdbpatch.sh /tmpRoot/usr/bin/deduplication.sh
  DEST="/tmpRoot/lib/systemd/system/deduplication.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Deduplication"                                     >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/bin/deduplication.sh"                                  >>${DEST}
  echo "ExecStop=/usr/bin/deduplication.sh"                                   >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/deduplication.service /tmpRoot/lib/systemd/system/multi-user.target.wants/deduplication.service
fi
