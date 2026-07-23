#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> & Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon netfix - ${1}"
  isSetting=false
  for F in $(LC_ALL=C printf '%s\n' /sys/class/net/eth* | sort -V); do
    [ ! -e "${F}" ] && continue
    ETH="$(basename "${F}")"
    MAC="$(cat "/sys/class/net/${ETH}/address" 2>/dev/null)"
    BUS="$(ethtool -i "${ETH}" 2>/dev/null | grep "bus-info" | cut -d' ' -f2)"
    if [ "${MAC}" = "00:00:00:00:00:00" ]; then
      RMAC=$(grep -Eo "R${BUS}=[^ ]*" /proc/cmdline | cut -d'=' -f2)
      if [ -n "${RMAC}" ]; then
        if ip link show "${ETH}" 2>/dev/null | grep -wq "state UP"; then isRunning=1; else isRunning=0; fi
        [ "${isRunning}" = "1" ] && ip link set dev "${ETH}" down
        ip link set dev "${ETH}" address "${RMAC}"
        [ "${isRunning}" = "1" ] && ip link set dev "${ETH}" up
        isSetting=true
      fi
    fi
  done
  [ "${isSetting}" = "true" ] && /etc/rc.network start
fi