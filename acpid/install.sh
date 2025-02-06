#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_acpid() {
  echo "Installing addon acpid - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/acpid-7.1.tgz -C /tmpRoot/usr/ ./bin ./sbin ./lib
  tar -zxf /addons/acpid-7.1.tgz -C /tmpRoot/ ./etc
}

uninstall_acpid() {
  echo "Uninstalling addon acpid - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -rf /tmpRoot/etc/acpi
  rm -f /tmpRoot/usr/bin/acpi_listen
  rm -f /tmpRoot/usr/sbin/acpid
  rm -f /tmpRoot/usr/sbin/kacpimon
}

case "${1}" in
  late)
    install_acpid "${1}"
    ;;
  uninstall)
    uninstall_acpid "${1}"
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac