#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon sspatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/sspatch.sh /tmpRoot/usr/bin/sspatch.sh
  cp -vf /usr/bin/patchelf /tmpRoot/usr/bin/patchelf
  cp -vf /usr/lib/libssutils.mitm.so /tmpRoot/usr/lib/libssutils.mitm.so
  
  SED_PATH='/tmpRoot/usr/bin/sed'
  ${SED_PATH} -i '/synopkg restart SurveillanceStation/d' /tmpRoot/etc/crontab
  # Add line to crontab, execute each minute
  echo "5       0       *       *       *       root    synopkg restart SurveillanceStation #arc sspatch addon" >>/tmpRoot/etc/crontab

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/sspatch.service"
  cat << EOF > ${DEST}
[Unit]
Description=addon sspatch
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