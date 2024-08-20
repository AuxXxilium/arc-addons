#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon sspatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/sspatch.sh /tmpRoot/usr/bin/sspatch.sh
  cp -vf /usr/bin/license.sh /tmpRoot/usr/bin/license.sh
  cp -vf /usr/bin/S82surveillance.sh /tmpRoot/usr/bin/S82surveillance.sh
  
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/sspatch.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon amepatch
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/sspatch.sh

[Install]
WantedBy=multi-user.target

[X-Synology]
Author=Virtualization Team
EOF

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/sspatch.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/sspatch.service
fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sspatch - ${1}"
  # To-Do
fi