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
    synopkg stop arc-control
    if ! synopkg uninstall arc-control; then
        echo "Arc Control: Uninstallation failed!"
        exit 1
    fi
}

# Function to install Python 3.11
install_python3() {
    if ! synopkg install /usr/arc/addons/python311.spk; then
        echo "Python 3.11: Installation failed!"
        exit 1
    fi
}

# Function to uninstall Python 3.11
uninstall_python3() {
    synopkg stop python311
    if ! synopkg uninstall python311; then
        echo "Python 3.11: Uninstallation failed!"
        exit 1
    fi
}

# Function to set permissions for Arc Control
set_arc_permissions() {
    if ! /var/packages/arc-control/target/app/install.sh; then
        echo "Arc Control: Setting permissions failed!"
        exit 1
    fi
}

# Function to start Python 3.11
start_python3() {
    synopkg stop python311
    if ! synopkg start python311; then
        echo "Python 3.11: Start failed!"
        exit 1
    fi
}

# Function to start Arc Control
start_arc_control() {
    synopkg stop arc-control
    if ! synopkg start arc-control; then
        echo "Arc Control: Start failed!"
        exit 1
    fi
}

# Main script execution
[ -f "/usr/arc/addons/python-3.11.spk" ] && rm -f "/usr/arc/addons/python-3.11.spk" || true
if [ "${APPUPDATE}" != "${APPVERSION}" ]; then
    if [ -d "/var/packages/arc-control" ]; then
        uninstall_arc_control
        sleep 2
    fi
    if [ -d "/var/packages/python311" ]; then
        uninstall_python3
        sleep 2
    fi
fi

if [ "${APPUPDATE}" != "${APPVERSION}" ]; then
    if [ ! -d "/var/packages/python311" ]; then
        install_python3
    fi
    sleep 2
    if [ -d "/var/packages/python311" ]; then
        start_python3
    fi
    sleep 2
    if [ ! -d "/var/packages/arc-control" ]; then
        install_arc_control
        set_arc_permissions
    fi
fi
sleep 2
if [ -d "/var/packages/arc-control" ]; then
    start_arc_control
fi
exit 0