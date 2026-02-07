#!/usr/bin/env sh
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

SSKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

for F in $(LC_ALL=C printf '%s\n' /sys/class/net/eth* | sort -V); do
  [ ! -e "${F}" ] && continue
  ETH="$(basename "${F}")"
  /usr/bin/ethtool -s "${ETH}" wol g 2>/dev/null
  WOL=$(/usr/bin/ethtool "${ETH}" 2>/dev/null | grep -E "^\s*Wake-on" | awk -F':' '{print $2}' | xargs)
  if [ "${WOL}" = "g" ]; then
    echo "${ETH} supports wol and set to g"
    /usr/bin/ethtool -s "${ETH}" wol g 2>/dev/null
    for CONF in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SSKV}" "${CONF}" "${ETH}_wol_options" "g"; done
  else
    echo "${ETH} does not support wol"
    for CONF in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SSKV}" "${CONF}" "${ETH}_wol_options" "d"; done
  fi
done