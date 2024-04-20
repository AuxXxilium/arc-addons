#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon lsiutil - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/sbin/lsiutil /tmpRoot/usr/sbin/lsiutil
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon lsiutil - ${1}"

  rm -f "/tmpRoot/usr/sbin/lsiutil"
fi
