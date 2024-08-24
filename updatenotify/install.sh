#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon updatenotify - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/pup /tmpRoot/usr/bin/pup
  cp -vf /usr/bin/arc-updatenotify.sh /tmpRoot/usr/bin/arc-updatenotify.sh
  
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arc-updatenotify.service"
  echo "[Unit]"                                         >${DEST}
  echo "Description=addon arc-updatenotify"            >>${DEST}
  echo "After=multi-user.target"                       >>${DEST}
  echo                                                 >>${DEST}
  echo "[Service]"                                     >>${DEST}
  echo "Type=oneshot"                                  >>${DEST}
  echo "RemainAfterExit=yes"                           >>${DEST}
  echo "ExecStart=/usr/bin/arc-updatenotify.sh create" >>${DEST}
  echo                                                 >>${DEST}
  echo "[Install]"                                     >>${DEST}
  echo "WantedBy=multi-user.target"                    >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-updatenotify.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-updatenotify.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arc-updatenotify - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-updatenotify.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/arc-updatenotify.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/arc-updatenotify.sh delete" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/pup /usr/bin/arc-updatenotify.sh" >>/tmpRoot/usr/arc/revert.sh
fi