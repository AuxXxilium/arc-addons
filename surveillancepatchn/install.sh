#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon surveillancepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/surveillancepatch.sh /tmpRoot/usr/bin/surveillancepatch.sh
  cp -vf /usr/lib/libssutils.so /tmpRoot/usr/lib/libssutils.so
  cp -vf /usr/lib/license.sh /tmpRoot/usr/lib/license.sh
  cp -vf /usr/lib/S82surveillance.sh /tmpRoot/usr/lib/S82surveillance.sh
  
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/surveillancepatch.service"
  echo "[Unit]"                                         >${DEST}
  echo "Description=addon surveillancepatch"           >>${DEST}
  echo "After=multi-user.target"                       >>${DEST}
  echo                                                 >>${DEST}
  echo "[Service]"                                     >>${DEST}
  echo "Type=oneshot"                                  >>${DEST}
  echo "RemainAfterExit=yes"                           >>${DEST}
  echo "ExecStart=/usr/bin/surveillancepatch.sh"       >>${DEST}
  echo                                                 >>${DEST}
  echo "[Install]"                                     >>${DEST}
  echo "WantedBy=multi-user.target"                    >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/surveillancepatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/surveillancepatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon surveillancepatch - ${1}"
  # To-Do
fi