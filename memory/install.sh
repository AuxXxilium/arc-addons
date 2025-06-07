#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon memory - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # memory.service
  cp -vpf /usr/bin/memory.sh /tmpRoot/usr/bin/memory.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/memory.service"
  {
    echo "[Unit]"
    echo "Description=memory daemon"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=-/usr/bin/memory.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/memory.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/memory.service
}

uninstall_addon() {
  echo "Uninstalling addon memory - ${1}"

  # memory.service
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/memory.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/memory.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/memory.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/memory.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
esac