#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon ledcontrol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/lib/modules/i2c* /tmpRoot/usr/lib/modules/
  cp -vf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/ledcontrol.sh
  cp -vf /usr/bin/ugreen_leds_cli /tmpRoot/usr/bin/ugreen_leds_cli
  modprobe i2c-algo-bit
  modprobe i2c-smbus
  modprobe i2c-i801

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  cat > ${DEST} <<EOF
[Unit]
Description=Adds Ledcontrol for Ugreen
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Restart=always
RestartSec=5
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh on

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ledcontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
fi