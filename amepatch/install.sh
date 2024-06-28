#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon amepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vf /usr/bin/amepatch.sh /tmpRoot/usr/bin/amepatch.sh

  if [ -f "/usr/bin/codecpatch.sh" ]; then
    echo -e "AME Patch: Codecpatch found -> skipping"
  else
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/amepatch.service"
    echo "[Unit]"                                         >${DEST}
    echo "Description=addon amepatch"                    >>${DEST}
    echo "After=multi-user.target"                       >>${DEST}
    echo                                                 >>${DEST}
    echo "[Service]"                                     >>${DEST}
    echo "Type=oneshot"                                  >>${DEST}
    echo "RemainAfterExit=yes"                           >>${DEST}
    echo "ExecStart=/usr/bin/amepatch.sh"                >>${DEST}
    echo                                                 >>${DEST}
    echo "[Install]"                                     >>${DEST}
    echo "WantedBy=multi-user.target"                    >>${DEST}

    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/amepatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon amepatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/amepatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/amepatch.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/amepatch.sh" >>/tmpRoot/usr/arc/revert.sh
fi
