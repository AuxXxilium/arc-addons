#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

APPVESION="1.1-14"
VERSION="$(cat /var/packages/arc-control/INFO | grep "version" | cut -d '"' -f 2)"
if [ ! -d "/var/packages/python311" ]; then
    # Install Python 3.11
    synopkg install /usr/arc/addons/python-3.11.spk
    if [ $? -ne 0 ]; then
        echo "Python 3.11: Installation failed!"
        exit 1
    fi
fi
sleep 2
if [ -d "/var/packages/python311" ]; then
    # Start Python 3.11
    synopkg restart python311
fi
sleep 2
if [ ! -d "/var/packages/arc-control" ] || [ "${VERSION}" != "${APPVERSION}" ]; then
    # Install Arc Control
    synopkg install /usr/arc/addons/arc-control.spk
    if [ $? -ne 0 ]; then
        echo "Arc Control: Installation failed!"
        exit 1
    fi
    # Set permissions
    mv /var/packages/arc-control/conf/privilege /tmp
    # use the custom privilege file
    mv /var/packages/arc-control/conf/privilege_ /var/packages/arc-control/conf/privilege
    # apply root privilege to the package
    sed -i 's/package/root/g' /var/packages/arc-control/conf/privilege
    # Remove the task from the scheduler
    cat /var/packages/arc-control/target/app/tasks.sql | sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db 
    # Add sudoers for loader disk
    echo -e "sc-arc-control ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/99-arc-control /etc.defaults/sudoers.d/99-arc-control > /dev/null
    chmod 0440 /etc/sudoers.d/99-arc-control /etc.defaults/sudoers.d/99-arc-control
fi
sleep 2
if [ -d "/var/packages/arc-control" ]; then
    # Start Arc Control
    synopkg restart arc-control
fi