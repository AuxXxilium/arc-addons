#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "rcExit" ]; then
  echo "Installing addon rndis - ${1}"
  
  /usr/bin/rndis.sh
elif [ "${1}" = "late" ]; then
  echo "Installing addon rndis - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/rndis.sh /tmpRoot/usr/bin/rndis.sh

  mkdir -p /tmpRoot/usr/lib/udev/rules.d
  echo 'SUBSYSTEMS=="net", KERNEL=="usb*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="rndis.service"' >/tmpRoot/usr/lib/udev/rules.d/99-rndis.rules
  chmod a+r /tmpRoot/usr/lib/udev/rules.d/99-rndis.rules

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/rndis.service"
  echo "[Unit]"                                   > ${DEST}
  echo "Description=Android USB Network Adapter"  >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo "ConditionPathExists=/sys/class/net/usb0"  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=simple"                              >>${DEST}
  echo "Restart=always"                           >>${DEST}
  echo "ExecStart=/usr/bin/rndis.sh"              >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/rndis.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/rndis.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon rndis - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/rndis.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/rndis.service"

  rm -f "/tmpRoot/usr/lib/udev/rules.d/99-rndis.rules"
  rm -f "/tmpRoot/usr/bin/rndis.sh"
fi