#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/diskdbpatch.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec DiskDBPatch"
  cp -vf /usr/bin/diskdbpatch.sh /tmpRoot/usr/bin/diskdbpatch.sh
  DEST="/tmpRoot/lib/systemd/system/diskdbpatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable DiskDBPatch"                                       >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/bin/diskdbpatch.sh -nrf"                               >>${DEST}
  echo "ExecStop=/usr/bin/diskdbpatch.sh -nrf"                                >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/diskdbpatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/diskdbpatch.service
fi
