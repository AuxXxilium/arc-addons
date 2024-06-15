#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon sequentialio - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/sequentialio.sh /tmpRoot/usr/bin/sequentialio.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/sequentialio.service"
  echo "[Unit]"                                    >${DEST}
  echo "Description=Sequential I/O SSD caches"    >>${DEST}
  echo "After=multi-user.target"                  >>${DEST}
  echo                                            >>${DEST}
  echo "[Service]"                                >>${DEST}
  echo "Type=oneshot"                             >>${DEST}
  echo "RemainAfterExit=yes"                      >>${DEST}
  echo "ExecStart=/usr/bin/sequentialio.sh $@"    >>${DEST}
  echo                                            >>${DEST}
  echo "[Install]"                                >>${DEST}
  echo "WantedBy=multi-user.target"               >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/sequentialio.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sequentialio.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sequentialio - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sequentialio.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/sequentialio.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/sequentialio.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/sequentialio.sh" >> /tmpRoot/usr/arc/revert.sh
fi