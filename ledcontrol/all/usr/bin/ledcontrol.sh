#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/sbin/ugreen_leds_cli"

_ugreen_pid() { ps aux 2>/dev/null | grep -F "/usr/sbin/ugreen_led" | grep -v grep | awk '{print $2}' | head -1; }

_pid="$(_ugreen_pid)"
if [ -n "${_pid}" ]; then
    kill -9 "${_pid}" 2>/dev/null || true
fi

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -on -color 255 255 255 -brightness 26
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -off
else
    if [ -z "$(_ugreen_pid)" ]; then
        "/usr/sbin/ugreen_led" &
    fi
fi

exit 0