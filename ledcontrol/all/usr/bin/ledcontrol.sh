#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/sbin/ugreen_leds_cli"

# By exact process name. Matching "/usr/sbin/ugreen_led" in the command line also
# hit /usr/sbin/ugreen_leds_cli, which the daemon spawns for every LED write, and
# only the first match was killed - so it could take out a CLI call, leave the
# daemon running, and start a second one beside it. Arc Control restarts the
# daemon this way after saving a disk LED map, and a survivor would keep
# driving the old one.
_ugreen_running() { pkill -0 -x ugreen_led 2>/dev/null; }

pkill -9 -x ugreen_led 2>/dev/null || true
# The kill is not instant, and "auto" below only starts a daemon if none is
# listed, so give the old one a moment to go.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    _ugreen_running || break
    sleep 0.2
done

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -on -color 255 255 255 -brightness 26
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    ${UGREEN_LEDS_CLI} all -off
else
    if ! _ugreen_running; then
        "/usr/sbin/ugreen_led" &
    fi
fi

exit 0