#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

APPUPDATE="1.1-17"
APPVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/arc-control/INFO)"

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
    mv /var/packages/arc-control/conf/privilege /tmp
    mv /var/packages/arc-control/conf/privilege_ /var/packages/arc-control/conf/privilege
    sed -i 's/package/root/g' /var/packages/arc-control/conf/privilege
}

# Function to remove task from scheduler
remove_scheduler_task() {
    if ! cat /var/packages/arc-control/target/app/tasks.sql | sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db; then
        echo "Arc Control: Failed to remove task from scheduler!"
        exit 1
    fi
}

# Function to add sudoers for loader disk
add_sudoers() {
    if ! echo -e "sc-arc-control ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/99-arc-control /etc.defaults/sudoers.d/99-arc-control > /dev/null; then
        echo "Arc Control: Failed to add sudoers!"
        exit 1
    fi
    chmod 0440 /etc/sudoers.d/99-arc-control /etc.defaults/sudoers.d/99-arc-control
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
    sleep 2
fi

if [ "${APPUPDATE}" != "${APPVERSION}" ]; then
    if [ ! -d "/var/packages/python311" ]; then
        if ! synopkg install /usr/arc/addons/python-3.11.spk; then
            echo "Python 3.11: Installation failed!"
            exit 1
        fi
    fi
    sleep 2
    if [ -d "/var/packages/python311" ]; then
        if ! synopkg restart python311; then
            echo "Python 3.11: Start failed!"
            exit 1
        fi
    fi
    sleep 2
    if [ ! -d "/var/packages/arc-control" ]; then
        install_arc_control
        set_permissions
        remove_scheduler_task
        add_sudoers
    fi
    sleep 2
    if [ -d "/var/packages/arc-control" ]; then
        start_arc_control
    fi
fi