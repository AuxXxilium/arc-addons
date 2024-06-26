#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon codecpatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/codecpatch.sh /tmpRoot/usr/bin/codecpatch.sh

  if [ -f "/usr/bin/amepatch.sh" ]; then
    cp -vf /usr/bin/amepatch.sh /tmpRoot/usr/bin/amepatch.sh

    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/codecpatch.service"
    echo "[Unit]"                                         >${DEST}
    echo "Description=addon codecpatch"                  >>${DEST}
    echo "After=multi-user.target"                       >>${DEST}
    echo                                                 >>${DEST}
    echo "[Service]"                                     >>${DEST}
    echo "Type=oneshot"                                  >>${DEST}
    echo "RemainAfterExit=yes"                           >>${DEST}
    echo "ExecStartPre=/bin/ash /usr/bin/codecpatch.sh"  >>${DEST}
    echo "ExecStart=/bin/ash /usr/bin/amepatch.sh"       >>${DEST}
    echo                                                 >>${DEST}
    echo "[Install]"                                     >>${DEST}
    echo "WantedBy=multi-user.target"                    >>${DEST}
  else
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/codecpatch.service"
    echo "[Unit]"                                         >${DEST}
    echo "Description=addon codecpatch"                  >>${DEST}
    echo "After=multi-user.target"                       >>${DEST}
    echo                                                 >>${DEST}
    echo "[Service]"                                     >>${DEST}
    echo "Type=oneshot"                                  >>${DEST}
    echo "RemainAfterExit=yes"                           >>${DEST}
    echo "ExecStart=/bin/ash /usr/bin/codecpatch.sh"     >>${DEST}
    echo                                                 >>${DEST}
    echo "[Install]"                                     >>${DEST}
    echo "WantedBy=multi-user.target"                    >>${DEST}
  fi
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/codecpatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon codecpatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/codecpatch.service"
  rm -f "/tmpRoot/usr/bin/codecpatch.sh"
  [ -f "/tmpRoot/usr/bin/amepatch.sh" ] && rm -f "/tmpRoot/usr/bin/amepatch.sh"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/codecpatch.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/codecpatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi