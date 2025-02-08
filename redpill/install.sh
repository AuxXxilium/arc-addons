#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -e

install_addon() {
  PLATFORMS="epyc7002"
  PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
  if ! echo "${PLATFORMS}" | grep -qw "${PLATFORM}"; then
    echo "${PLATFORM} is not supported redpill addon!"
    exit 0
  fi

  case "${1}" in
    early)
      echo "Installing addon redpill - early"
      insmod /usr/lib/modules/rp.ko
      ;;
    jrExit)
      echo "Installing addon redpill - jrExit"
      #rmmod redpill
      ;;
    *)
      exit 0
      ;;
  esac
}

install_addon "${1}"