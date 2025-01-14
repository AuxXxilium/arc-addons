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

  local files=(
    "/usr/bin/acpi_listen"
    "/usr/bin/acpitool"
    "/usr/sbin/acpid"
    "/usr/sbin/kacpimon"
  )
  
  for file in "${files[@]}"; do
    dest="/tmpRoot${file}"
    cp -f "$file" "$dest"
    chown root:root "$dest"
  done
  
  mkdir -p /tmpRoot/usr/etc/acpi
  chmod 755 /tmpRoot/usr/etc/acpi
  chown root:root /tmpRoot/usr/etc/acpi
  
  cp -rf /usr/etc/acpi/* /tmpRoot/usr/etc/acpi/
  chown root:root /tmpRoot/usr/etc/acpi/*

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/acpid.service"
  {
    echo "[Unit]"
    echo "Description=ACPI Daemon"
    echo "DefaultDependencies=no"
    echo "IgnoreOnIsolate=true"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=forking"
    echo "Restart=always"
    echo "RestartSec=30"
    echo "PIDFile=/var/run/acpid.pid"
    echo "ExecStartPre=/usr/sbin/modprobe button"
    echo "ExecStart=/usr/sbin/acpid"
    echo "ExecStopPost=/usr/sbin/modprobe -r button"
    echo
    echo "[X-Synology]"
    echo "Author=Virtualization Team"
  } >"${DEST}"
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/acpid.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon acpid - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/acpid.service"

  rm -rf /tmpRoot/etc/acpi
  rm -f /tmpRoot/usr/bin/acpi_listen
  rm -f /tmpRoot/usr/sbin/acpid
  rm -f /tmpRoot/usr/sbin/kacpimon
fi