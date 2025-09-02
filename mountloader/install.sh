#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon mountloader - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/usr/mountloader
  tar -zxf /addons/mountloader-7.1.tgz -C /tmpRoot/usr/mountloader

  cp -vpf /usr/bin/yq /tmpRoot/usr/bin/yq
  cp -vpf /usr/bin/unzip /tmpRoot/usr/bin/unzip
  if [ -f /usr/bin/arcsu ]; then
    cp -vpf /usr/bin/arcsu /tmpRoot/usr/bin/arcsu
    chown root:root /tmpRoot/usr/bin/arcsu
    chmod 4755 /tmpRoot/usr/bin/arcsu
  fi
  cp -pf /usr/bin/arc-loaderdisk.sh /tmpRoot/usr/bin/arc-loaderdisk.sh
  
  rm -f /tmpRoot/usr/arc/.mountloader
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon mountloader - ${1}"

  rm -f "/tmpRoot/usr/bin/arc-loaderdisk.sh"
  rm -f "/tmpRoot/usr/bin/arcsu"
fi