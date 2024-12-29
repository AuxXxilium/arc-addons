#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

APPUPDATE="1.1-19"
APPVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/arc-control/INFO | head -n1)"

# Function to install Arc Control
install_arc_control() {
    if ! synopkg install /usr/arc/addons/arc-control.spk; then
        echo "Arc Control: Installation failed!"
        exit 1
    fi
}

# Function to uninstall Arc Control
uninstall_arc_control() {
    if ! synopkg uninstall arc-control; then
        echo "Arc Control: Uninstallation failed!"
        exit 1
    fi
}

# Function to set permissions for Arc Control
set_permissions() {
    if ! /var/packages/arc-control/target/app/install.sh; then
        echo "Arc Control: Setting permissions failed!"
        exit 1
    fi
}

# Function to start Arc Control
start_arc_control() {
    if ! synopkg restart arc-control; then
        echo "Arc Control: Start failed!"
        exit 1
    fi
}

# Main script execution
if [ -d "/var/packages/arc-control" ] && [ "${APPUPDATE}" != "${APPVERSION}" ]; then
    uninstall_arc_control
    sleep 5
fi

if [ ! -d "/var/packages/arc-control" ] || [ "${APPUPDATE}" != "${APPVERSION}" ]; then
    if [ ! -d "/var/packages/python311" ]; then
        if ! synopkg install /usr/arc/addons/python311.spk; then
            echo "Python 3.11: Installation failed!"
            exit 1
        fi
    fi
    sleep 3
    if [ -d "/var/packages/python311" ]; then
        if ! synopkg restart python311; then
            echo "Python 3.11: Start failed!"
            exit 1
        fi
    fi
    sleep 3
    if [ ! -d "/var/packages/arc-control" ]; then
        install_arc_control
        set_permissions
    fi
fi
sleep 3
if [ -d "/var/packages/arc-control" ]; then
    start_arc_control
fi
exit 0