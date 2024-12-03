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
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/ledcontrol.sh
  cp -pf /usr/bin/ugreen_leds_cli /tmpRoot/usr/bin/ugreen_leds_cli
  cp -pf /usr/bin/modules/i2c-algo-bit.ko /tmpRoot/usr/bin/modules/i2c-algo-bit.ko
  cp -pf /usr/lib/modules/i2c-i801.ko /tmpRoot/usr/lib/modules/i2c-i801.ko
  cp -pf /usr/lib/modules/i2c-smbus.ko /tmpRoot/usr/lib/modules/i2c-smbus.ko
  if [ -f "/tmpRoot/usr/bin/ledcontrol.sh" ]; then
    chmod a+x /tmpRoot/usr/bin/ledcontrol.sh
    chmod u+s /tmpRoot/usr/bin/ledcontrol.sh
  fi
  if [ -f "/tmpRoot/usr/bin/ugreen_leds_cli" ]; then
    chmod a+x /tmpRoot/usr/bin/ugreen_leds_cli
    chmod u+s /tmpRoot/usr/bin/ugreen_leds_cli
  fi
  if [ -f "/tmpRoot/usr/bin/ping" ]; then
    chmod a+x /tmpRoot/usr/bin/ping
    chmod u+s /tmpRoot/usr/bin/ping
  fi
  if [ -f "/tmpRoot/usr/bin/sensors" ]; then
    chmod a+x /tmpRoot/usr/bin/sensors
    chmod u+s /tmpRoot/usr/bin/sensors
  fi

  insmod i2c-algo-bit
  insmod i2c-i801
  insmod i2c-smbus

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  # All on
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  {
    echo "[Unit]"
    echo "Description=Adds uGreen LED control"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=simple"
    echo "Restart=on-failure"
    echo "RestartSec=10"
    echo "ExecStart=/usr/bin/ledcontrol.sh ${2}"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ledcontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
fi