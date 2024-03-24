#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon codecpatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/codecpatch.sh /tmpRoot/usr/bin/codecpatch.sh

  DEST="/tmpRoot/usr/lib/systemd/system/codecpatch.service"
  echo "[Unit]"                                         >${DEST}
  echo "Description=addon codecpatch"                  >>${DEST}
  echo "After=multi-user.target"                       >>${DEST}
  echo                                                 >>${DEST}
  echo "[Service]"                                     >>${DEST}
  echo "Type=oneshot"                                  >>${DEST}
  echo "RemainAfterExit=yes"                           >>${DEST}
  echo "ExecStart=/usr/bin/codecpatch.sh -p"           >>${DEST}
  echo                                                 >>${DEST}
  echo "[Install]"                                     >>${DEST}
  echo "WantedBy=multi-user.target"                    >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/codecpatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon codecpatch - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/codecpatch.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/codecpatch.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/codecpatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi
