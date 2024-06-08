#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon revert - ${1}"

  mkdir -p "/tmpRoot/usr/arc/"
  echo '#!/usr/bin/env bash' >"/tmpRoot/usr/arc/revert.sh"
  chmod +x "/tmpRoot/usr/arc/revert.sh"
  
  mkdir -p "/tmpRoot/usr/arc/addons/"
  for F in $(ls /tmpRoot/usr/arc/addons/* 2>/dev/null); do
    if grep -q "/addons/${F##*/}" "/addons/addons.sh" 2>/dev/null; then continue; fi
    chmod +x "${F}" || true
    "${F}" "uninstall" || true
    rm -f "${F}" || true
  done

  if [ ! "$(cat "/tmpRoot/usr/arc/revert.sh")" = '#!/usr/bin/env bash' ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/revert.service"
    echo "[Unit]"                                    >${DEST}
    echo "Description=revert"                       >>${DEST}
    echo "After=multi-user.target"                  >>${DEST}
    echo                                            >>${DEST}
    echo "[Service]"                                >>${DEST}
    echo "Type=oneshot"                             >>${DEST}
    echo "RemainAfterExit=yes"                      >>${DEST}
    echo "ExecStart=-/usr/arc/revert.sh"            >>${DEST}
    echo                                            >>${DEST}
    echo "[Install]"                                >>${DEST}
    echo "WantedBy=multi-user.target"               >>${DEST}

    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/revert.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service
  else
    rm -f "/tmpRoot/usr/lib/systemd/system/revert.service"
    rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service"
  fi

  # backup current loader configs
  rm -rf "/tmpRoot/usr/arc/backup"
  if [ -d "/usr/arc/backup" ]; then
    mkdir -p "/tmpRoot/usr/arc/backup"
    cp -rf /usr/arc/backup/* "/tmpRoot/usr/arc/backup/"
  fi

  # Version
  echo "LOADERLABEL=\"${LOADERLABEL}\""      >"/tmpRoot/usr/arc/VERSION"
  echo "LOADERVERSION=\"${LOADERVERSION}\"" >>"/tmpRoot/usr/arc/VERSION"

fi