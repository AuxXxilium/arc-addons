#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

for N in $(ls /sys/class/net/ 2>/dev/null | grep eth); do
  echo "set ${N} wol g"
  /usr/bin/ethtool -s "${N}" wol g
done