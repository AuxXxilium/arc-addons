#!/usr/bin/env ash

if [ "${1}" = "jrExit" ]; then
  echo "Installing addon wol - ${1}"
  for N in $(ls /sys/class/net/ 2>/dev/null | grep eth); do
    /usr/bin/ethtool -s ${N} wol g 2>/dev/null
  done
elif [ "${1}" = "late" ]; then
  echo "Installing addon wol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/ethtool /tmpRoot/usr/bin/ethtool
  cp -vf /usr/bin/wol.sh /tmpRoot/usr/bin/wol.sh

  DEST="/tmpRoot/lib/systemd/system/ethtool.service"
  echo "[Unit]"                                                               > ${DEST}
  echo "Description=Arc force WoL on ethN"                                    >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/bin/wol.sh"                                            >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/ethtool.service /tmpRoot/lib/systemd/system/multi-user.target.wants/ethtool.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon wol - ${1}"

  rm -f "/tmpRoot/lib/systemd/system/multi-user.target.wants/ethtool.service"
  rm -f "/tmpRoot/lib/systemd/system/ethtool.service"

  #rm -f /tmpRoot/usr/bin/ethtool
  rm -f /tmpRoot/usr/bin/wol.sh
fi
