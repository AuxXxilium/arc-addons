#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# From：https://github.com/007revad/Synology_enable_Deduplication
#

set -e

install_addon() {
  echo "Creating service to exec deduplication"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/deduplication.sh /tmpRoot/usr/bin/deduplication.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/deduplication.service"
  {
    echo "[Unit]"
    echo "Description=Enable Deduplication"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/deduplication.sh -t"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/deduplication.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service
}

uninstall_addon() {
  echo "Uninstalling addon deduplication"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/deduplication.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/deduplication.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/deduplication.sh --restore" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/deduplication.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon
    ;;
  *)
    exit 0
    ;;
esac