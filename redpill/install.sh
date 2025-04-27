#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  SUPPORTED="false"
  PLATFORMS="epyc7002 v1000nk"
  PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"

  # Check if the platform is supported
  for SUPPORTED_PLATFORM in ${PLATFORMS}; do
    if [ "${PLATFORM}" = "${SUPPORTED_PLATFORM}" ]; then
      SUPPORTED="true"
      break
    fi
  done

  if [ "${SUPPORTED}" != "true" ]; then
    echo "${PLATFORM} is not supported for the redpill addon!"
    exit 1
  fi

  # Handle installation based on the argument
  case "${1}" in
    early)
      echo "Installing addon redpill - early"
      insmod /usr/lib/modules/rp.ko
      ;;
    jrExit)
      echo "Installing addon redpill - jrExit"
      rmmod redpill
      ;;
    *)
      exit 0
      ;;
  esac
}

install_addon "${1}"
exit 0