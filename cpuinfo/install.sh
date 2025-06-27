#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_cpuinfo() {
  echo "Installing addon cpuinfo - late"
  mkdir -p /tmpRoot/usr/arc/addons/ /tmpRoot/usr/sbin /tmpRoot/usr/bin /tmpRoot/usr/lib/systemd/system/multi-user.target.wants

  cp -pf "$0" /tmpRoot/usr/arc/addons/
  cp -vpf /usr/sbin/cpuinfo /tmpRoot/usr/sbin/cpuinfo
  cp -vpf /usr/bin/cpuinfo.sh /tmpRoot/usr/bin/cpuinfo.sh

  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/cpuinfo.service"
[Unit]
Description=cpuinfo daemon
After=synoscgi.service nginx.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/cpuinfo.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/cpuinfo.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service
}

uninstall_cpuinfo() {
  echo "Uninstalling addon cpuinfo - uninstall"
  rm -f /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service
  rm -f /tmpRoot/usr/lib/systemd/system/cpuinfo.service
  [ ! -f /tmpRoot/usr/arc/revert.sh ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/cpuinfo.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/cpuinfo.sh" >>/tmpRoot/usr/arc/revert.sh
  rm -f /tmpRoot/usr/sbin/cpuinfo
}

case "$1" in
  late) install_cpuinfo ;;
  uninstall) uninstall_cpuinfo ;;
esac