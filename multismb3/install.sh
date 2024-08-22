#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Multi-SMB3"
  cp -vf /usr/bin/smb3-multi.sh /tmpRoot/usr/bin/smb3-multi.sh

  DEST="/tmpRoot/usr/lib/systemd/system/smb3-multi.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Multi-SMB3"                                        >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/bin/smb3-multi.sh"                                     >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/smb3-multi.service /tmpRoot/lib/systemd/system/multi-user.target.wants/smb3-multi.service
fi