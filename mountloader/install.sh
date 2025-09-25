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

  cp -pf /usr/bin/arc-loaderdisk.sh /tmpRoot/usr/bin/arc-loaderdisk.sh

  cp -vpf /usr/bin/yq /tmpRoot/usr/bin/yq
  cp -vpf /usr/bin/unzip /tmpRoot/usr/bin/unzip

  if [ -f /usr/bin/arcsu ]; then
    cp -vpf /usr/bin/arcsu /tmpRoot/usr/bin/arcsu
    chown root:root /tmpRoot/usr/bin/arcsu
    chmod u+s /tmpRoot/usr/bin/arcsu
  fi

  [ ! -f /tmpRoot/sbin/fatlabel ] && cp -vpf /usr/sbin/fatlabel /tmpRoot/sbin/fatlabel
  [ ! -f /tmpRoot/sbin/dosfslabel ] && ln -vsf fatlabel /tmpRoot/sbin/dosfslabel
  [ ! -f /tmpRoot/sbin/fsck.fat ] && cp -vpf /usr/sbin/fsck.fat /tmpRoot/sbin/fsck.fat
  [ ! -f /tmpRoot/sbin/dosfsck ] && ln -vsf fsck.fat /tmpRoot/sbin/dosfsck
  [ ! -f /tmpRoot/sbin/fsck.msdos ] && ln -vsf fsck.fat /tmpRoot/sbin/fsck.msdos
  [ ! -f /tmpRoot/sbin/fsck.vfat ] && ln -vsf fsck.fat /tmpRoot/sbin/fsck.vfat
  [ ! -f /tmpRoot/sbin/mkfs.fat ] && cp -vpf /usr/sbin/mkfs.fat /tmpRoot/sbin/mkfs.fat
  [ ! -f /tmpRoot/sbin/mkdosfs ] && ln -vsf mkfs.fat /tmpRoot/sbin/mkdosfs
  [ ! -f /tmpRoot/sbin/mkfs.msdos ] && ln -vsf mkfs.fat /tmpRoot/sbin/mkfs.msdos
  [ ! -f /tmpRoot/sbin/mkfs.vfat ] && ln -vsf mkfs.fat /tmpRoot/sbin/mkfs.vfat

  rm -f /tmpRoot/usr/arc/.mountloader
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon mountloader - ${1}"

  rm -f "/tmpRoot/usr/bin/arc-loaderdisk.sh"
  rm -f "/tmpRoot/usr/bin/arcsu"
fi