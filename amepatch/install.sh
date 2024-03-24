#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon amepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/amepatch.sh /tmpRoot/usr/bin/amepatch.sh
  cp -vf /usr/bin/awk /tmpRoot/usr/bin/awk
  cp -vf /usr/bin/xxd /tmpRoot/usr/bin/xxd

  DEST="/tmpRoot/usr/lib/systemd/system/amepatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable AME Patch"                                         >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/bin/amepatch.sh"                                       >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/amepatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/amepatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon amepatch - ${1}"
  #TODO: Add uninstall code here
fi
