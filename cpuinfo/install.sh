#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon cpuinfo - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # cpuinfo
  cp -vpf /usr/bin/cpuinfo.sh /tmpRoot/usr/bin/cpuinfo.sh

  shift
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/cpuinfo.service"
  {
    echo "[Unit]"
    echo "Description=cpuinfo daemon"
    echo "After=multi-user.target synoscgi.service nginx.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/cpuinfo.sh" "$@"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/cpuinfo.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service

  # synoscgiproxy
  cp -vpf /usr/sbin/synoscgiproxy /tmpRoot/usr/sbin/synoscgiproxy

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon cpuinfo - ${1}"

  # cpuinfo
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpuinfo.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/cpuinfo.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/cpuinfo.sh" >>/tmpRoot/usr/arc/revert.sh

  # synoscgiproxy
  rm -f /tmpRoot/usr/sbin/synoscgiproxy
fi