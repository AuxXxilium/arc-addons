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
  
  cp -vf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/ledcontrol.sh
  cp -vf /usr/bin/ugreen_leds_cli /tmpRoot/usr/bin/ugreen_leds_cli
  cp -vf /usr/bin/led.conf /tmpRoot/usr/bin/led.conf
  cp -vf /usr/bin/modules/i2c-algo-bit.ko /tmpRoot/usr/bin/modules/i2c-algo-bit.ko
  cp -vf /usr/lib/modules/i2c-i801.ko /tmpRoot/usr/lib/modules/i2c-i801.ko
  cp -vf /usr/lib/modules/i2c-smbus.ko /tmpRoot/usr/lib/modules/i2c-smbus.ko
  modprobe i2c-algo-bit
  modprobe i2c-i801
  modprobe i2c-smbus

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_cpu.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.service"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
# All on
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  cat << EOF > ${DEST}
[Unit]
Description=Ledcontrol for Ugreen
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=10s
ExecStart=/usr/bin/ledcontrol.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ledcontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_cpu.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
fi