#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon hdddb - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/hdddb.sh /tmpRoot/usr/bin/hdddb.sh

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/hdddb.service"
  cat > ${DEST} <<EOF
[Unit]
Description=HDDs/SSDs drives databases
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/hdddb.sh -n -f -r -e -i -w -p

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/hdddb.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon hdddb - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/hdddb.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/hdddb.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/hdddb.sh" >> /tmpRoot/usr/arc/revert.sh
fi