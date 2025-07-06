#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/sbin/ugreen_leds_cli"

if ps -aux | grep -v grep | grep -q "/usr/sbin/ugreen_led" >/dev/null; then
    /usr/bin/pkill -f "/usr/sbin/ugreen_led"
fi

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -on -color 255 255 255 -brightness 26
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -off
else
    if ! ps aux | grep -v grep | grep -q "/usr/sbin/ugreen_led" >/dev/null; then
        "/usr/sbin/ugreen_led" &
    fi
fi

exit 0