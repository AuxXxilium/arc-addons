#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon sensors - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/sensors-7.1.tgz -C /tmpRoot/usr/
  if [ ! -f "/tmpRoot/usr/arc/addons/fancontrol.sh" ]; then
    [ -f "/tmpRoot/etc/fancontrol" ] && rm -f /tmpRoot/etc/fancontrol
  fi

  [ -f "/tmpRoot/usr/bin/arc-sensors.sh" ] && rm -f /tmpRoot/usr/bin/arc-sensors.sh
  [ -e "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service" ] && rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
  [ -e "/tmpRoot/usr/lib/systemd/system/sensors.service" ] && rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sensors - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sensors.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/sensors.service"
fi