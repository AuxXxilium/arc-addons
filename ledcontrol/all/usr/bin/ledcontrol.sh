#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/bin/ugreen_leds_cli"

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -on -color 255 255 255 -brightness 255
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -off
else
    # Initialize device status array
    devices=(p f x x x x x x x x)
    # Initialize device mapping
    map=(power netdev disk1 disk2 disk3 disk4 disk5 disk6 disk7 disk8)

    # Check network status, red blinking alert for network disconnection
    echo "Checking network status..."
    gw=$(ip route | awk '/default/ { print$3 }')
    if ping -q -c 1 -W 1 $gw >/dev/null; then
        devices[1]=w
    else
        devices[1]=r
    fi

    # Map sataX to hardware devices
    declare -A hwmap

    echo "Mapping devices..."
    for devpath in /sys/block/sata*; do
        dev=$(basename $devpath)
        hctl=$(basename $(readlink $devpath/device))
        hwmap[$dev]=${hctl:0:1}
        echo "Mapped $dev to ${hctl:0:1}"
    done

    # Print hardware mapping (hwmap) for verification
    echo "Hardware mapping (hwmap):"
    for key in "${!hwmap[@]}"; do
        echo "$key:${hwmap[$key]}"
    done

    # Check disk status and update device status array
    echo "Checking disk status..."
    for dev in "${!hwmap[@]}"; do
        # Use udevadm to check disk status
        if udevadm info --query=all --name=/dev/$dev &> /dev/null; then
            status="ONLINE"
        else
            status="OFFLINE"
        fi
        index=$((${hwmap[$dev]} + 2))
        echo "Device $dev status $status mapped to index $index"

        if [ $status = "ONLINE" ]; then
            devices[$index]=b
        else
            devices[$index]=o
        fi
    done

    # Get CPU temperature (requires sensors plugin)
    cpu_temp=$(sensors | awk '/Core 0/ {print$3}' | cut -c2- | cut -d'.' -f1)

    # Set power LED status based on CPU temperature, red blinking alert for 90 degrees
    if [ "$cpu_temp" -ge 90 ]; then
        devices[0]=r
    else
        devices[0]=g
    fi

    # Set disk LED status based on disk temperature, red blinking alert for 50 degrees
    for i in "${!hwmap[@]}"; do
        index=$((${hwmap[$i]} + 2))
        hdd_temp=$(cat /run/synostorage/disks/sata$((${hwmap[$i]} + 1))/temperature)
        if [ "$hdd_temp" -ge 50 ]; then
            devices[$index]=r
        else
            devices[$index]=b
        fi
    done

    # Output final device status and control LED lights
    echo "Final device status:"
    for i in "${!devices[@]}"; do
        echo "$i:${devices[$i]}"
        case "${devices[$i]}" in
            r)
                echo "Set ${map[$i]} to red blinking"
                ${UGREEN_LEDS_CLI} ${map[$i]} -color 255 0 0 -blink 400 600 -brightness 64
                ;;
            g)
                echo "Set ${map[$i]} to green solid"
                ${UGREEN_LEDS_CLI} ${map[$i]} -color 0 255 0 -on -brightness 64
                ;;
            b)
                echo "Set ${map[$i]} to blue solid"
                ${UGREEN_LEDS_CLI} ${map[$i]} -color 0 0 255 -on -brightness 64
                ;;
            w)
                echo "Set ${map[$i]} to white solid"
                ${UGREEN_LEDS_CLI} ${map[$i]} -color 255 255 255 -on -brightness 64
                ;;
            o)
                echo "Turn off ${map[$i]}"
                ${UGREEN_LEDS_CLI} ${map[$i]} -off
                ;;
        esac
    done
fi
exit 0