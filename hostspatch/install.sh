#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Hostspatch"
  cp -vf /usr/sbin/hostspatch.sh /tmpRoot/usr/sbin/hostspatch.sh
  
  DEST="/tmpRoot/lib/systemd/system/hostspatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Hostspatch"                                        >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/sbin/hostspatch.sh"                                    >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/hostspatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/hostspatch.service
fi