#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ugreen_leds_cli all -on -color 255 255 255 -brightness 65
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ugreen_leds_cli all -off
elif [ "${1}" = "blink" ]; then
    echo "Blink Ugreen LED"
    ugreen_leds_cli all -blink -color 255 255 255 -brightness 65
elif [ "${1}" = "install" ]; then
    modprobe i2c-algo-bit
    modprobe i2c-smbus
    modprobe i2c-i801
fi
exit 0