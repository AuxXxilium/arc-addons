#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon ledcontrol - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/sbin/" "/tmpRoot/usr/lib/modules/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/
  cp -pf /usr/sbin/ugreen_leds_cli /tmpRoot/usr/sbin/
  cp -pf /usr/sbin/ugreen_led /tmpRoot/usr/sbin/
  cp -pf /usr/lib/modules/i2c-algo-bit.ko /tmpRoot/usr/lib/modules/ || true
  cp -pf /usr/lib/modules/i2c-i801.ko /tmpRoot/usr/lib/modules/ || true
  cp -pf /usr/lib/modules/i2c-smbus.ko /tmpRoot/usr/lib/modules/ || true

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
Type=one-shot
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/ledcontrol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service
}

uninstall_addon() {
  echo "Uninstalling addon ledcontrol - ${1}"

  # Remove systemd files
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service" \
        "/tmpRoot/usr/lib/systemd/system/ledcontrol.service" \
        "/tmpRoot/usr/arc/addons/ledcontrol.sh" \
        "/tmpRoot/usr/bin/ugreen_leds_cli" \
        "/tmpRoot/usr/bin/ugreen_led"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  echo "/usr/bin/ledcontrol.sh" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/ledcontrol.sh" >> /tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  late) install_addon "${1}" "${2}" ;;
  uninstall) uninstall_addon "${1}" ;;
esac