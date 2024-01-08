#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for CertUpdate"
  cp -vf /usr/sbin/certupdate.sh /tmpRoot/usr/sbin/certupdate.sh

  DEST="/tmpRoot/lib/systemd/system/certupdate.service"
  echo "[Unit]"                                        >${DEST}
  echo "Description=Update Cert"                      >>${DEST}
  echo "After=multi-user.target"                      >>${DEST}
  echo                                                >>${DEST}
  echo "[Service]"                                    >>${DEST}
  echo "Type=oneshot"                                 >>${DEST}
  echo "RemainAfterExit=true"                         >>${DEST}
  echo "ExecStart=/usr/sbin/certupdate.sh"                >>${DEST}
  echo                                                >>${DEST}
  echo "[Install]"                                    >>${DEST}
  echo "WantedBy=multi-user.target"                   >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/certupdate.service /tmpRoot/lib/systemd/system/multi-user.target.wants/certupdate.service
fi
