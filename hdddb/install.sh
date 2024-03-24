#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon hdddb - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/hdddb.sh /tmpRoot/usr/bin/hdddb.sh

  DEST="/tmpRoot/usr/lib/systemd/system/hdddb.service"
  echo "[Unit]"                                    >${DEST}
  echo "Description=HDDs/SSDs drives databases"   >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=oneshot"                             >>${DEST}
  echo "RemainAfterExit=yes"                      >>${DEST}
  echo "ExecStart=/usr/bin/hdddb.sh -nfie"        >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/hdddb.service /tmpRoot/lib/systemd/system/multi-user.target.wants/hdddb.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon hdddb - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/hdddb.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/hdddb.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/hdddb.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/hdddb.sh" >> /tmpRoot/usr/arc/revert.sh
fi