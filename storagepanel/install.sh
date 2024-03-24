#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon storagepanel - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/storagepanel.sh /tmpRoot/usr/bin/storagepanel.sh
  shift
  DEST="/tmpRoot/usr/lib/systemd/system/storagepanel.service"
  echo "[Unit]"                                          >${DEST}
  echo "Description=Modify storage panel"               >>${DEST}
  echo "After=multi-user.target"                        >>${DEST}
  echo                                                  >>${DEST}
  echo "[Service]"                                      >>${DEST}
  echo "Type=oneshot"                                   >>${DEST}
  echo "RemainAfterExit=yes"                            >>${DEST}
  echo "ExecStart=/usr/bin/storagepanel.sh $1 $2"       >>${DEST}
  echo                                                  >>${DEST}
  echo "[Install]"                                      >>${DEST}
  echo "WantedBy=multi-user.target"                     >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/storagepanel.service /tmpRoot/lib/systemd/system/multi-user.target.wants/storagepanel.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon storagepanel - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/storagepanel.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/storagepanel.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/storagepanel.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/storagepanel.sh" >>/tmpRoot/usr/arc/revert.sh
fi
