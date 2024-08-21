#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon expands - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/expands.sh /tmpRoot/usr/bin/expands.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/expands.service"
  echo "[Unit]"                                    >${DEST}
  echo "Description=Expanded miscellaneous"       >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=oneshot"                             >>${DEST}
  echo "RemainAfterExit=yes"                      >>${DEST}
  echo "ExecStart=-/usr/bin/expands.sh"           >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/expands.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/expands.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon expands - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/expands.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/expands.service"

  FILE="/tmpRoot/usr/syno/etc.defaults/usb.map"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
  FILE="/tmpRoot/etc/ssl/certs/ca-certificates.crt"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
fi
