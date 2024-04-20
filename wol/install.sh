#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "jrExit" ]; then
  echo "Installing addon wol - ${1}"
  for N in $(ls /sys/class/net/ 2>/dev/null | grep eth); do
    /usr/bin/ethtool -s ${N} wol g 2>/dev/null
  done
elif [ "${1}" = "late" ]; then
  echo "Installing addon wol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  [ ! -f "/tmpRoot/usr/bin/ethtool" ] && cp -vf /usr/bin/ethtool /tmpRoot/usr/bin/ethtool
  cp -vf /usr/bin/wol.sh /tmpRoot/usr/bin/wol.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/wol.service"
  echo "[Unit]"                                   > ${DEST}
  echo "Description=ARPL force WoL on ethN"       >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=oneshot"                             >>${DEST}
  echo "RemainAfterExit=yes"                      >>${DEST}
  echo "ExecStart=/usr/bin/wol.sh"                >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/wol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon wol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/wol.service"

  # rm -f /tmpRoot/usr/bin/ethtool
  rm -f /tmpRoot/usr/bin/wol.sh
fi