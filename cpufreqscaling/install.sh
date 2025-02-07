#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  rm -f "/tmpRoot/usr/bin/scaling.sh"
  cp -pf "/usr/sbin/scaling.sh" "/tmpRoot/usr/sbin/scaling.sh"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  local DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
  {
    echo "[Unit]"
    echo "Description=Enable CPU Freq scaling"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "User=root"
    echo "Type=simple"
    echo "Restart=on-failure"
    echo "RestartSec=10"
    echo "ExecStart=/usr/sbin/scaling.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  ln -vsf "/usr/lib/systemd/system/cpufreqscaling.service" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/sbin/scaling.sh"
fi