#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -e

install_addon() {
  echo "Installing addon powersched - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  [ ! -f "/tmpRoot/usr/sbin/powersched.bak" -a -f "/tmpRoot/usr/sbin/powersched" ] && cp -pf "/tmpRoot/usr/sbin/powersched" "/tmpRoot/usr/sbin/powersched.bak"
  cp -pf "/usr/sbin/powersched" "/tmpRoot/usr/sbin/powersched"
  chmod 755 "/tmpRoot/usr/sbin/powersched"

  # Clean old entries
  [ ! -f "/tmpRoot/etc/crontab.bak" -a -f "/tmpRoot/etc/crontab" ] && cp -f "/tmpRoot/etc/crontab" "/tmpRoot/etc/crontab.bak"
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab

  # Add line to crontab, execute each minute
  echo "*       *       *       *       *       root    /usr/sbin/powersched #arpl powersched addon" >>/tmpRoot/etc/crontab
}

uninstall_addon() {
  echo "Uninstalling addon powersched - ${1}"

  [ -f "/tmpRoot/usr/sbin/powersched.bak" ] && mv -f "/tmpRoot/usr/sbin/powersched.bak" "/tmpRoot/usr/sbin/powersched"
  [ -f "/tmpRoot/etc/crontab.bak" ] && mv -f "/tmpRoot/etc/crontab.bak" "/tmpRoot/etc/crontab"
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    echo "Usage: ${0} {late|uninstall}"
    exit 1
    ;;
esac