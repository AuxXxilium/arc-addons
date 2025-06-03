#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

_release=$(/bin/uname -r)
if [ "$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1)" -lt 5 ]; then
  echo "Kernel version < 5 is not supported redpill addon!"
  exit 0
fi

# Handle installation based on the argument
case "${1}" in
  early)
    echo "Installing addon redpill - early"
    insmod /usr/lib/modules/rp.ko
    ;;
  jrExit)
    echo "Installing addon redpill - jrExit"
    #rmmod redpill
    ;;
esac