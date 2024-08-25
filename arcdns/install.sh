#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon arcdns - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/arcdns.sh /tmpRoot/usr/bin/arcdns.sh
  
  SED_PATH='/tmpRoot/usr/bin/sed'
  ${SED_PATH} -i '/\/usr\/bin\/arcdns.sh/d' /tmpRoot/etc/crontab
  # Add line to crontab, execute each minute
  echo "*/5       *       *       *       *       root    /usr/bin/arcdns.sh ${2} #arcdns addon" >>/tmpRoot/etc/crontab

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/arcdns.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon arcdns
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=10
ExecStart=/usr/bin/arcdns.sh "${2}"

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arcdns.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arcdns.service
fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arcdns - ${1}"
  # To-Do
fi