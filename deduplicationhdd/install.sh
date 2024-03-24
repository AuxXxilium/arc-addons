#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec deduplicationhdd"
  cp -vf /usr/sbin/deduplicationhdd.sh /tmpRoot/usr/sbin/deduplicationhdd.sh
  
  DEST="/tmpRoot/usr/lib/systemd/system/deduplicationhdd.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable Deduplication HDD"                                 >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/bin/deduplicationhdd.sh --hdd -e"                      >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/deduplicationhdd.service /tmpRoot/lib/systemd/system/multi-user.target.wants/deduplicationhdd.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon deduplicationhdd - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/deduplicationhdd.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/deduplicationhdd.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/deduplication.sh --restore" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/deduplication.sh" >>/tmpRoot/usr/arc/revert.sh
fi
