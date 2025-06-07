#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon revert - ${1}"

  mkdir -p "/tmpRoot/usr/arc/"
  mkdir -p "/tmpRoot/usr/arc/addons/"

  echo '#!/usr/bin/env bash' >"/tmpRoot/usr/arc/revert.sh"
  chmod +x "/tmpRoot/usr/arc/revert.sh"
  
  for F in /tmpRoot/usr/arc/addons/*; do
    [ ! -e "${F}" ] && continue
    grep -q "/addons/$(basename "${F}")" "/addons/addons.sh" 2>/dev/null && continue
    chmod +x "${F}" || true
    "${F}" "uninstall" || true
    rm -f "${F}" || true
  done

  if [ "$(cat "/tmpRoot/usr/arc/revert.sh")" != '#!/usr/bin/env bash' ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/revert.service"
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
    } >"${DEST}"
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/revert.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service
  else
    rm -f "/tmpRoot/usr/lib/systemd/system/revert.service"
    rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/revert.service"
  fi

  # Backup loader config
  rm -rf "/tmpRoot/usr/arc"
  if [ -d "/usr/arc" ]; then
    mkdir -p "/tmpRoot/usr/arc"
    cp -rpf /usr/arc/* "/tmpRoot/usr/arc/"
  fi
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
esac