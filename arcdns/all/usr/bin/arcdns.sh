#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

cp -f /usr/bin/arcdns.php /usr/syno/bin/ddns/arcdns.php

ENTRIES=("[Custom - ArcDNS]")
for ENTRY in "${ENTRIES[@]}"
do
if [ -f "/etc/ddns_provider.conf" ]; then
    if grep -Fxq "${ENTRY}" /etc/ddns_provider.conf; then
        echo "arcdns: Entry ${ENTRY} already exists"
    else
        echo "arcdns: Entry ${ENTRY} does not exist, adding now"
        echo "${ENTRY}" >> /etc/ddns_provider.conf
        echo "        modulepath=/usr/syno/bin/ddns/arcdns.php" >> /etc/ddns_provider.conf
        echo "        queryurl=https://arcdns.tech/update/__HOSTNAME__/__PASSWORD__" >> /etc/ddns_provider.conf
    fi
fi
if [ -f "/etc.defaults/ddns_provider.conf" ]; then
    if grep -Fxq "${ENTRY}" /etc.defaults/ddns_provider.conf; then
        echo "arcdns: Entry ${ENTRY} already exists"
    else
        echo "arcdns: Entry ${ENTRY} does not exist, adding now"
        echo "${ENTRY}" >> /etc.defaults/ddns_provider.conf
        echo "        modulepath=/usr/syno/bin/ddns/arcdns.php" >> /etc.defaults/ddns_provider.conf
        echo "        queryurl=https://arcdns.tech/update/__HOSTNAME__/__PASSWORD__" >> /etc.defaults/ddns_provider.conf
    fi
fi
done