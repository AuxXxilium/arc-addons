#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec DiskDBPatch"
  cp -vf /usr/sbin/diskdbpatch.sh /tmpRoot/usr/sbin/diskdbpatch.sh
  chmod 755 /tmpRoot/usr/sbin/diskdbpatch.sh

  DEST="/tmpRoot/lib/systemd/system/diskdbpatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable DiskDBPatch"                                       >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/diskdbpatch.sh -nrf"                              >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/diskdbpatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/diskdbpatch.service
fi
