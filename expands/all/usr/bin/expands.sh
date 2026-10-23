#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "-r" ]; then
  # usb.map
  FILE="/usr/syno/etc/usb.map"
  /usr/bin/arc-backup.sh restore "${FILE}"

  # ca-certificates.crt
  FILE="/etc/ssl/certs/ca-certificates.crt"
  /usr/bin/arc-backup.sh restore "${FILE}"
else
  # usb.map
  FILE="/usr/syno/etc/usb.map"
  if [ -f "${FILE}" ]; then
    STATUS=$(curl -kL -w "%{http_code}" "http://www.linux-usb.org/usb.ids" -o "/tmp/usb.map")
    if [ $? -ne 0 ] || [ ${STATUS} -ne 200 ]; then
      echo "usb.ids download error!"
    else
      /usr/bin/arc-backup.sh take "${FILE}"
      cp -vpf "/tmp/usb.map" "${FILE}"
      /usr/bin/arc-backup.sh seal "${FILE}"
    fi
  fi

  # ca-certificates.crt
  FILE="/etc/ssl/certs/ca-certificates.crt"
  if [ -f "${FILE}" ]; then
    STATUS=$(curl -kL -w "%{http_code}" "https://curl.se/ca/cacert.pem" -o "/tmp/cacert.pem")
    if [ $? -ne 0 ] || [ ${STATUS} -ne 200 ]; then
      echo "ca-certificates.crt download error!"
    else
      /usr/bin/arc-backup.sh take "${FILE}"
      cp -vpf "/tmp/cacert.pem" "${FILE}"
      /usr/bin/arc-backup.sh seal "${FILE}"
    fi
  fi
fi

exit 0