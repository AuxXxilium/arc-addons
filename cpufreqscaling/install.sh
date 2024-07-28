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
  [ ! -f "/tmpRoot/usr/bin/echo" ] && cp -vf /usr/bin/echo /tmpRoot/usr/bin/echo

  if [ "${2}" = "userspace" ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
    cat << EOF > ${DEST}
[Unit]
Description=Enable CPU Freq scaling
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10s
ExecStart=/usr/sbin/scaler.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
  else
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
    cat << EOF > ${DEST}
[Unit]
Description=Enable CPU Freq scaling
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
RemainAfterExit=yes
ExecStart=/usr/sbin/rescaler.sh ${2}

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing cpufreqscalingscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"

  rm -f /tmpRoot/usr/sbin/scaler.sh
  rm -f /tmpRoot/usr/sbin/rescaler.sh
  rm -f /tmpRoot/usr/sbin/unscaler.sh
fi