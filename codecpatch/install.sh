#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_codecpatch() {
  echo "Installing addon codecpatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/codecpatch.sh /tmpRoot/usr/bin/codecpatch.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  local DEST="/tmpRoot/usr/lib/systemd/system/codecpatch.service"
  {
    echo "[Unit]"
    echo "Description=addon codecpatch"
    echo "After=syno-volume.target syno-space.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/codecpatch.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/codecpatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service
}

uninstall_codecpatch() {
  echo "Uninstalling addon codecpatch - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/codecpatch.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/codecpatch.service"
  rm -f "/tmpRoot/usr/bin/codecpatch.sh"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/codecpatch.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/codecpatch.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_codecpatch "${1}"
    ;;
  uninstall)
    uninstall_codecpatch "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac