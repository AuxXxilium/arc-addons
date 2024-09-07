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

  cp -vf /usr/bin/arcdns.php /tmpRoot/usr/syno/bin/ddns/arcdns.php
  
  # Define the entries to be added
  ENTRIES=("[Custom - ArcDNS]")
  for ENTRY in "${ENTRIES[@]}"
  do
    if [ -f "/tmpRoot/etc.defaults/ddns_provider.conf" ]; then
        if grep -Fxq "${ENTRY}" /tmpRoot/etc.defaults/ddns_provider.conf; then
          echo "arcdns: Entry ${ENTRY} already exists"
        else
          echo "arcdns: Entry ${ENTRY} does not exist, adding now"
          echo "${ENTRY}" >> /tmpRoot/etc.defaults/ddns_provider.conf
          echo "        modulepath=/usr/syno/bin/ddns/namecheap.php" >> /tmpRoot/etc.defaults/ddns_provider.conf
          echo "        queryurl=https://arcdns.tech/update/__HOSTNAME__/__PASSWORD__" >> /tmpRoot/etc.defaults/ddns_provider.conf
        fi
    fi
  done

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon arcdns - ${1}"
  # To-Do
fi