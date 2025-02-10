#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon updatenotify - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/pup /tmpRoot/usr/bin/pup
  cp -pf /usr/bin/arc-updatenotify.sh /tmpRoot/usr/bin/arc-updatenotify.sh
  
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arc-updatenotify.service"
  {
    echo "[Unit]"
    echo "Description=addon arc-updatenotify"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/arc-updatenotify.sh create"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-updatenotify.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-updatenotify.service
}

uninstall_addon() {
  echo "Uninstalling addon updatenotify - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-updatenotify.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/arc-updatenotify.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/arc-updatenotify.sh delete" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/pup /usr/bin/arc-updatenotify.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0