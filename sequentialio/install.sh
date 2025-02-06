#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_sequentialio() {
  echo "Installing addon sequentialio - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/sequentialio.sh /tmpRoot/usr/bin/sequentialio.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  local DEST="/tmpRoot/usr/lib/systemd/system/sequentialio.service"
  {
    echo "[Unit]"
    echo "Description=Sequential I/O SSD caches"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/sequentialio.sh $@"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/sequentialio.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sequentialio.service
}

uninstall_sequentialio() {
  echo "Uninstalling addon sequentialio - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sequentialio.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/sequentialio.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/sequentialio.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/sequentialio.sh" >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_sequentialio "${1}"
    ;;
  uninstall)
    uninstall_sequentialio "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac