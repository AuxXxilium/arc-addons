#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon ledcontrol - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/sbin/" "/tmpRoot/usr/lib/modules/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/ledcontrol.sh || true
  cp -pf /usr/sbin/ugreen_leds_cli /tmpRoot/usr/sbin/ugreen_leds_cli || true
  cp -pf /usr/sbin/ugreen_led /tmpRoot/usr/sbin/ugreen_led || true
  cp -pf /usr/lib/modules/i2c-algo-bit.ko /tmpRoot/usr/lib/modules/i2c-algo-bit.ko || true
  cp -pf /usr/lib/modules/i2c-i801.ko /tmpRoot/usr/lib/modules/i2c-i801.ko || true
  cp -pf /usr/lib/modules/i2c-smbus.ko /tmpRoot/usr/lib/modules/i2c-smbus.ko || true

  # Not setuid. Everything that runs them is root already: ledcontrol.service,
  # ledcontrol.sh from Arc Control's CGIs (root through arcsu or the package's
  # own root privilege), and ugreen_led itself, which runs ugreen_leds_cli for
  # every LED write. Setuid root only gave every local account - the web
  # server's user, any SSH login - the front panel's raw i2c and the daemon
  # that runs arcsu, as root. 0755 rather than leaving it to cp: a copy that
  # failed above would keep the setuid bit an older loader set.
  chmod 0755 "/tmpRoot/usr/sbin/ugreen_leds_cli" "/tmpRoot/usr/sbin/ugreen_led" 2>/dev/null || true

  # Load kernel modules
  insmod i2c-algo-bit
  insmod i2c-i801
  insmod i2c-smbus

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
[Unit]
Description=Adds uGreen LED control
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/ledcontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon ledcontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  rm -f "/tmpRoot/usr/bin/ledcontrol.sh"
  rm -f "/tmpRoot/usr/sbin/ugreen_leds_cli"
  rm -f "/tmpRoot/usr/sbin/ugreen_led"

fi