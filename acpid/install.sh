#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
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
  sed -i '/^Exec/s|=/|=/|g' /tmpRoot/usr/lib/systemd/system/acpid.service
  if [ -f /usr/lib/modules/button.ko ]; then
    cp -pf /usr/lib/modules/button.ko /tmpRoot/usr/lib/modules/button.ko
  else
    echo "No button.ko found"
  fi

  # mkdir -p "/tmpRoot/usr/lib/systemd/system"
  # DEST="/tmpRoot/usr/lib/systemd/system/acpid.service"
  # {
  #   echo "[Unit]"
  #   echo "Description=ACPI Daemon"
  #   echo "DefaultDependencies=no"
  #   echo "IgnoreOnIsolate=true"
  #   echo "After=multi-user.target"
  #   echo
  #   echo "[Service]"
  #   echo "Type=forking"
  #   echo "Restart=always"
  #   echo "RestartSec=30"
  #   echo "PIDFile=/var/run/acpid.pid"
  #   echo "ExecStartPre=/usr/sbin/modprobe button"
  #   echo "ExecStart=/usr/sbin/acpid"
  #   echo "ExecStopPost=/usr/sbin/modprobe -r button"
  #   echo
  #   echo "[X-Synology]"
  #   echo "Author=Virtualization Team"
  # } >"${DEST}"
  # mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  # ln -vsf /usr/lib/systemd/system/acpid.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon acpid - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -rf /tmpRoot/etc/acpi
  rm -f /tmpRoot/usr/bin/acpi_listen
  rm -f /tmpRoot/usr/sbin/acpid
  rm -f /tmpRoot/usr/sbin/kacpimon
fi