#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Deduplication"
  cp -vf /usr/sbin/diskdbpatch.sh /tmpRoot/usr/sbin/deduplication.sh
  chmod 755 /tmpRoot/usr/sbin/dedublication.sh

  DEST="/tmpRoot/lib/systemd/system/deduplication.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Deduplication"                                     >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/deduplication.sh"                                 >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/deduplication.service /tmpRoot/lib/systemd/system/multi-user.target.wants/deduplication.service
fi
