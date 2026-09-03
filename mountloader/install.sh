#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
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

  rm -f /tmpRoot/usr/bin/arcsu
  cp -vpf /usr/bin/arcsu /tmpRoot/usr/bin/arcsu
  chown root:root /tmpRoot/usr/bin/arcsu
  chmod u+s /tmpRoot/usr/bin/arcsu

  # dosfstools: /sbin is a symlink to /usr/sbin in DSM, so install into
  # /usr/sbin like every other addon. misc ships these too; this is the
  # fallback for when mountloader is installed without it.
  mkdir -p /tmpRoot/usr/sbin
  for f in fatlabel fsck.fat mkfs.fat; do
    cp -pf "/usr/sbin/${f}" "/tmpRoot/usr/sbin/${f}"
  done
  ln -sf fatlabel /tmpRoot/usr/sbin/dosfslabel
  ln -sf fsck.fat /tmpRoot/usr/sbin/dosfsck
  ln -sf fsck.fat /tmpRoot/usr/sbin/fsck.msdos
  ln -sf fsck.fat /tmpRoot/usr/sbin/fsck.vfat
  ln -sf mkfs.fat /tmpRoot/usr/sbin/mkdosfs
  ln -sf mkfs.fat /tmpRoot/usr/sbin/mkfs.msdos
  ln -sf mkfs.fat /tmpRoot/usr/sbin/mkfs.vfat

  rm -f /tmpRoot/usr/arc/.mountloader
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon mountloader - ${1}"

  rm -rf "/tmpRoot/usr/mountloader"
  rm -f "/tmpRoot/usr/bin/arc-loaderdisk.sh"
  rm -f "/tmpRoot/usr/bin/arcsu"
fi