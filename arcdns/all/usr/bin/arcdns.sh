#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
ARCHOST="${1}"

if curl "${ARCHOST}" -o /tmp/arcdns; then
    if cat /tmp/arcdns | grep -q "Successfuly updated"; then
        IP=$(cat /tmp/arcdns | grep "current_ip" | sed 's/.*current_ip":"\([0-9.]*\).*/\1/')
        echo "ArcDNS: IP updated to ${IP}"
        rm -f /tmp/arcdns
        exit 0
    else
        echo "ArcDNS: Failed to update IP"
        rm -f /tmp/arcdns
        exit 1
    fi
else
    echo "ArcDNS: Can't connect to the server"
    exit 1
fi