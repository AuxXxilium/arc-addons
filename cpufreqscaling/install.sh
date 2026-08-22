#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing cpufreqscaling - ${1}"

  mkdir -p /tmpRoot/usr/arc/addons/ /tmpRoot/usr/sbin /tmpRoot/usr/bin /tmpRoot/usr/lib/modules /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/sbin/scaling.sh /tmpRoot/usr/sbin/scaling.sh

  CPUFREQ_MODULES="acpi_cpufreq cpufreq_governor cpufreq_stats cpufreq_ondemand cpufreq_conservative cpufreq_performance cpufreq_powersave cpufreq_userspace"
  for M in ${CPUFREQ_MODULES}; do
    if [ -f "/usr/lib/modules/${M}.ko" ]; then
      cp -pf "/usr/lib/modules/${M}.ko" /tmpRoot/usr/lib/modules/ || true
    fi
  done

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
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling cpufreqscaling - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service" \
        "/tmpRoot/usr/lib/systemd/system/cpufreqscaling.service" \
        "/tmpRoot/usr/sbin/scaling.sh"
fi