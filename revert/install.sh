#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon revert - ${1}"

  mkdir -p "/tmpRoot/usr/arc/addons/"

  echo '#!/usr/bin/env bash' >"/tmpRoot/usr/arc/revert.sh"
  chmod +x "/tmpRoot/usr/arc/revert.sh"
  
  for F in $(LC_ALL=C printf '%s\n' /tmpRoot/usr/arc/addons/* | sort -V); do
    [ ! -e "${F}" ] && continue
    grep -q "/addons/$(basename "${F}")" "/addons/addons.sh" 2>/dev/null && continue
    chmod +x "${F}" || true
    "${F}" "uninstall" || true
    rm -f "${F}" || true
  done

  if [ "$(cat "/tmpRoot/usr/arc/revert.sh")" != '#!/usr/bin/env bash' ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    {
      echo "[Unit]"
      echo "Description=revert"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Type=oneshot"
      echo "RemainAfterExit=yes"
      echo "ExecStart=/usr/arc/revert.sh"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"/tmpRoot/usr/lib/systemd/system/revert.service"

    mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -sf /usr/lib/systemd/system/revert.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service
  else
    rm -f "/tmpRoot/usr/lib/systemd/system/revert.service"
    rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service"
  fi

  # Backup loader config
  rm -f "/tmpRoot/usr/arc/VERSION" 2>/dev/null
  rm -rf "/tmpRoot/usr/arc/backup" 2>/dev/null
  if [ -f "/usr/arc/VERSION" ]; then
    cp -pf /usr/arc/VERSION "/tmpRoot/usr/arc/VERSION"
  fi
  if [ -d "/usr/arc/backup" ]; then
    mkdir -p "/tmpRoot/usr/arc/backup"
    cp -raf /usr/arc/backup/* "/tmpRoot/usr/arc/backup/"
  fi
  [ -f "/tmpRoot/usr/arc/backup/p1/VERSION" ] && rm -f "/tmpRoot/usr/arc/backup/p1/VERSION"
fi