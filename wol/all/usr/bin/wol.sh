#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

for F in /sys/class/net/eth*; do
  [ ! -e "${F}" ] && continue
  ETH="$(basename "${F}")"
  echo "set ${F} wol g"
  /usr/bin/ethtool -s "${ETH}" wol g 2>/dev/null
done
exit 0