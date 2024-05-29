#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Creating service to exec deduplication"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/deduplication.sh /tmpRoot/usr/bin/deduplication.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"  
  DEST="/tmpRoot/usr/lib/systemd/system/deduplication.service"
  echo "[Unit]"                                    >${DEST}
  echo "Description=Enable Deduplication"         >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=oneshot"                             >>${DEST}
  echo "RemainAfterExit=yes"                      >>${DEST}
  echo "ExecStart=/usr/bin/deduplication.sh -st"  >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/deduplication.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon deduplication - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/deduplication.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/deduplication.sh --restore" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/deduplication.sh" >>/tmpRoot/usr/arc/revert.sh
fi
