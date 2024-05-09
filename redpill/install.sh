#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORMS="epyc7002"
PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
if ! echo "${PLATFORMS}" | grep -qw "${PLATFORM}"; then
  echo "${PLATFORM} is not supported redpill addon!"
  exit 0
fi

if [ "${1}" = "early" ]; then
  echo "Installing addon redpill - ${1}"

  insmod /usr/lib/modules/rp.ko

elif [ "${1}" = "jrExit" ]; then
  echo "Installing addon redpill - ${1}"

  #rmmod redpill
fi