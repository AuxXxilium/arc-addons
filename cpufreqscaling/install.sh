#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/sbin/scaler.sh /tmpRoot/usr/sbin/scaler.sh
  cp -vf /usr/sbin/unscaler.sh /tmpRoot/usr/sbin/unscaler.sh
  cp -vf /usr/sbin/rescaler.sh /tmpRoot/usr/sbin/rescaler.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
  echo "[Unit]"                                              >${DEST}
  echo "Description=Enable CPU Freq scaling"                 >>${DEST}
  echo "DefaultDependencies=no"                              >>${DEST}
  echo "IgnoreOnIsolate=true"                                >>${DEST}
  echo "After=multi-user.target"                             >>${DEST}
  echo                                                       >>${DEST}
  echo "[Service]"                                           >>${DEST}
  echo "User=root"                                           >>${DEST}
  echo "Restart=always"                                      >>${DEST}
  echo "RestartSec=30"                                       >>${DEST}
  echo "ExecStart=/usr/sbin/scaler.sh"                       >>${DEST}
  echo                                                       >>${DEST}
  echo "[X-Synology]"                                        >>${DEST}
  echo "Author=Virtualization Team"                          >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"

  rm -f /tmpRoot/usr/sbin/scaler.sh
  rm -f /tmpRoot/usr/sbin/rescaler.sh
  rm -f /tmpRoot/usr/sbin/unscaler.sh
fi