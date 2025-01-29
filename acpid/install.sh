#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon acpid - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/acpid-7.1.tgz -C /tmpRoot/usr/ ./bin ./sbin ./lib
  tar -zxf /addons/acpid-7.1.tgz -C /tmpRoot/ ./etc

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon acpid - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -rf /tmpRoot/etc/acpi
  rm -f /tmpRoot/usr/bin/acpi_listen
  rm -f /tmpRoot/usr/sbin/acpid
  rm -f /tmpRoot/usr/sbin/kacpimon
fi