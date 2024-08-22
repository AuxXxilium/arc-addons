#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "jrExit" ]; then
  echo "Installing addon wol - ${1}"
  for N in $(ls /sys/class/net/ 2>/dev/null | grep eth); do
    /usr/bin/ethtool -s ${N} wol g 2>/dev/null
  done
elif [ "${1}" = "late" ]; then
  echo "Installing addon wol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  [ ! -f "/tmpRoot/usr/bin/ethtool" ] && cp -vf /usr/bin/ethtool /tmpRoot/usr/bin/ethtool
  cp -vf /usr/bin/wol.sh /tmpRoot/usr/bin/wol.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/wol.service"
  cat <<EOF > ${DEST}
[Unit]
Description=Force WOL on ethN
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wol.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/wol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon wol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/wol.service"

  # rm -f /tmpRoot/usr/bin/ethtool
  rm -f /tmpRoot/usr/bin/wol.sh
fi