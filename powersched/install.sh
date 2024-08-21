#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon powersched - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  [ ! -f "/tmpRoot/usr/sbin/powersched.bak" -a -f "/tmpRoot/usr/sbin/powersched" ] && cp -vf "/tmpRoot/usr/sbin/powersched" "/tmpRoot/usr/sbin/powersched.bak"
  cp -vf "/usr/sbin/powersched" "/tmpRoot/usr/sbin/powersched"
  chmod 755 "/tmpRoot/usr/sbin/powersched"
  # Clean old entries
  [ ! -f "/tmpRoot/etc/crontab.bak" -a -f "/tmpRoot/etc/crontab" ] && cp -f "/tmpRoot/etc/crontab" "/tmpRoot/etc/crontab.bak"
  SED_PATH='/tmpRoot/usr/bin/sed'
  ${SED_PATH} -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab
  # Add line to crontab, execute each minute
  echo "*       *       *       *       *       root    /usr/sbin/powersched #arc powersched addon" >>/tmpRoot/etc/crontab
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon powersched - ${1}"

  [ -f "/tmpRoot/usr/sbin/powersched.bak" ] && mv -f "/tmpRoot/usr/sbin/powersched.bak" "/tmpRoot/usr/sbin/powersched"
  [ -f "/tmpRoot/etc/crontab.bak" ] && mv -f "/tmpRoot/etc/crontab.bak" "/tmpRoot/etc/crontab"
fi