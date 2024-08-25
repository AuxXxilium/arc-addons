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

  cp -vf /usr/bin/scaler.sh /tmpRoot/usr/bin/scaler.sh
  cp -vf /usr/bin/unscaler.sh /tmpRoot/usr/bin/unscaler.sh
  cp -vf /usr/bin/rescaler.sh /tmpRoot/usr/bin/rescaler.sh
  [ ! -f "/tmpRoot/usr/bin/echo" ] && cp -vf /usr/bin/echo /tmpRoot/usr/bin/echo

  if [ "${2}" = "userspace" ]; then
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
    cat << EOF > ${DEST}
[Unit]
Description=Enable CPU Freq scaling
DefaultDependencies=no
IgnoreOnIsolate=true
After=udevrules.service

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=10
ExecStartPre=sleep 30
ExecStart=/usr/bin/scaler.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF
    mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
    ln -vsf /usr/lib/systemd/system/cpufreqscaling.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
  else
    [ "${2}" != "schedutil" ] && cp -vf /usr/lib/modules/cpufreq_${2}.ko /tmpRoot/usr/lib/modules/cpufreq_${2}.ko && modprobe cpufreq_${2}
    mkdir -p "/tmpRoot/usr/lib/systemd/system"
    DEST="/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
    cat << EOF > ${DEST}
[Unit]
Description=Enable CPU Freq scaling
DefaultDependencies=no
IgnoreOnIsolate=true
After=udevrules.service

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=10
ExecStart=/usr/bin/rescaler.sh "${2}"

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

  rm -f /tmpRoot/usr/bin/scaler.sh
  rm -f /tmpRoot/usr/bin/rescaler.sh
  rm -f /tmpRoot/usr/bin/unscaler.sh
fi