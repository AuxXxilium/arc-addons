#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing cpufreqscaling - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -pf "/usr/sbin/scaling.sh" "/tmpRoot/usr/sbin/"

  # Create systemd service file
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service"
[Unit]
Description=Enable CPU Freq scaling
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
Restart=no
ExecStart=/usr/sbin/scaling.sh

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf "/usr/lib/systemd/system/cpufreqscaling.service" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service"
}

uninstall_addon() {
  echo "Uninstalling cpufreqscaling - ${1}"

  # Remove systemd files and scripts
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service" \
        "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service" \
        "/tmpRoot/usr/sbin/scaling.sh"
}

case "${1}" in
  late) install_addon "${1}" ;;
  uninstall) uninstall_addon "${1}" ;;
esac