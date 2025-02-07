#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon cpuinfo - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -pf /usr/bin/cpuinfo.sh /tmpRoot/usr/bin/cpuinfo.sh

  shift
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  local DEST="/tmpRoot/usr/lib/systemd/system/cpuinfo.service"
  {
    echo "[Unit]"
    echo "Description=Adds correct CPU Info"
    echo "After=multi-user.target"
    echo "After=synoscgi.service nginx.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/cpuinfo.sh $@"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/cpuinfo.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service

  # synoscgiproxy
  cp -vpf /usr/sbin/synoscgiproxy /tmpRoot/usr/sbin/synoscgiproxy

  # for FILE in "/tmpRoot/etc/nginx/nginx.conf" "/tmpRoot/usr/syno/share/nginx/nginx.mustache"; do
  #   [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
  #   sed -i 's|/run/synoscgi.sock;|/run/synoscgi_rr.sock;|' "${FILE}"
  # done
  # 
  # mkdir -p "/tmpRoot/usr/lib/systemd/system"
  # DEST="/tmpRoot/usr/lib/systemd/system/synoscgiproxy.service"
  # {
  #   echo "[Unit]"
  #   echo "Description=ARC addon synoscgiproxy daemon"
  #   echo "After=network.target"
  #   echo
  #   echo "[Service]"
  #   echo "Type=simple"
  #   echo "ExecStart=/usr/sbin/synoscgiproxy"
  #   echo "ExecReload=/bin/kill -HUP \$MAINPID"
  #   echo "Restart=always"
  #   echo "RestartSec=3"
  #   echo "StartLimitInterval=60"
  #   echo "StartLimitBurst=3"
  #   echo
  #   echo "[Install]"
  #   echo "WantedBy=multi-user.target"
  # } >"${DEST}"
  # 
  # mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  # ln -vsf /usr/lib/systemd/system/synoscgiproxy.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/synoscgiproxy.service

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon cpuinfo - ${1}"

  # cpuinfo
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/cpuinfo.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/cpuinfo.service"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/cpuinfo.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/cpuinfo.sh" >>/tmpRoot/usr/arc/revert.sh

  # synoscgiproxy
  rm -f /tmpRoot/usr/sbin/synoscgiproxy

  # for FILE in "/tmpRoot/etc/nginx/nginx.conf" "/tmpRoot/usr/syno/share/nginx/nginx.mustache"; do
  #   [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"
  # done
  #
  # rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/synoscgiproxy.service"
  # rm -f "/tmpRoot/usr/lib/systemd/system/synoscgiproxy.service"
  # 
fi