#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

APPVESION="1.1-14"
VERSION="$(cat /var/packages/arc-control/INFO | grep "version" | cut -d '"' -f 2)"
if [ ! -d "/var/packages/arc-control" ] || [ "${VERSION}" != "${APPVERSION}" ]; then
    # Install Arc Control
    synopkg install /usr/arc/addons/arc-control.spk
    if [ $? -ne 0 ]; then
        echo "Arc Control: Installation failed!"
        exit 1
    fi
    # Set permissions
    /var/packages/arc-control/target/app/install.sh
    if [ $? -ne 0 ]; then
        echo "Arc Control: Failed to set permissions!"
        exit 1
    fi
    # Start Arc Control
    synopkg restart arc-control
fi