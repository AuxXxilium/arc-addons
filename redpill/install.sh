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

install_redpill_early() {
  echo "Installing addon redpill - early"
  insmod /usr/lib/modules/rp.ko
}

install_redpill_jrExit() {
  echo "Installing addon redpill - jrExit"
  #rmmod redpill
}

case "${1}" in
  early)
    install_redpill_early
    ;;
  jrExit)
    install_redpill_jrExit
    ;;
  *)
    echo "Invalid argument: ${1}"
    exit 1
    ;;
esac