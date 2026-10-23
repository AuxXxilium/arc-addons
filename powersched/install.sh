#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon powersched - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vpf /usr/sbin/powersched /tmpRoot/usr/sbin/powersched

  # Only the powersched line is ours, so only it is added and removed. A copy
  # of the whole crontab, put back on uninstall, would undo DSM's own entries
  # since and, after an update, bring back another release's.
  rm -f /tmpRoot/etc/crontab.bak
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null
  echo "*       *       *       *       *       root    /usr/sbin/powersched" >>/tmpRoot/etc/crontab

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon powersched - ${1}"

  rm -f /tmpRoot/usr/sbin/powersched
  rm -f /tmpRoot/etc/crontab.bak
  sed -i '/\/usr\/sbin\/powersched/d' /tmpRoot/etc/crontab 2>/dev/null
fi