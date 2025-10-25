#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon powersched - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/sbin/powersched /tmpRoot/usr/sbin/powersched

  [ ! -f "/tmpRoot/etc/crontab.bak" ] && [ -f "/tmpRoot/etc/crontab" ] && cp -pf "/tmpRoot/etc/crontab" "/tmpRoot/etc/crontab.bak"
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null
  echo "*       *       *       *       *       root    /usr/sbin/powersched" >>/tmpRoot/etc/crontab

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon powersched - ${1}"

  rm -f /tmpRoot/usr/sbin/powersched
  [ -f "/tmpRoot/etc/crontab.bak" ] && mv -f "/tmpRoot/etc/crontab.bak" "/tmpRoot/etc/crontab"
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null
fi