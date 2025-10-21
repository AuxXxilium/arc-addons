#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

_release=$(/bin/uname -r)
if [ "$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1)" -lt 5 ]; then
  echo " Kernel version < 5 is not supported by redpill addon!"
  exit 0
fi

if [ "${1}" = "early" ]; then
  echo "Installing addon redpill - ${1}"

  insmod /usr/lib/modules/rp.ko
elif [ "${1}" = "jrExit" ]; then
  echo "Installing addon redpill - ${1}"

  rmmod redpill
fi