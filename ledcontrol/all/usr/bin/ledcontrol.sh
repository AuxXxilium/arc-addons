#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/bin/ugreen_leds_cli"
SMARTCTL="/usr/bin/smartctl"
HDPARM="/usr/bin/hdparm"

# Funktion, um zu überprüfen, ob ein Netzwerkinterface verbunden ist
function check_network_interface() {
    local interface=$1
    ip link show dev ${interface} | grep -q "state UP"
    return $?
}

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -on -color 255 255 255 -brightness 255
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -off
else
    ${UGREEN_LEDS_CLI} all -off
    # NIC Status
    interface_up=0
    interfaces=$(ls /sys/class/net 2>/dev/null | grep eth)

    for interface in ${interfaces}; do
        if check_network_interface ${interface}; then
            interface_up=1
            break
        fi
    done

    if [ ${interface_up} -eq 1 ]; then
        ${UGREEN_LEDS_CLI} netdev -on -color 0 255 0 -brightness 255 >/dev/null 2>&1
    fi

    # CPU
    ${UGREEN_LEDS_CLI} power -on -color 255 255 255 -brightness 255 >/dev/null 2>&1

    # Disks
    devices=$(($(ls -d /dev/sata*[1-9] 2>/dev/null | grep -v 'p' | wc -l) - 1))
    disk_number=0
    while true; do
        disk_number=$((disk_number + 1))
        ${UGREEN_LEDS_CLI} disk${disk_number} -on -color 0 255 0 -brightness 255 >/dev/null 2>&1
        [ ${disk_number} -eq ${devices} ] && break
    done

fi
exit 0