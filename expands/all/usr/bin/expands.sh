#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# usb.map
FILE="/usr/syno/etc/usb.map"
if [ -f "${FILE}" ]; then
  STATUS=$(curl -kL -w "%{http_code}" "http://www.linux-usb.org/usb.ids" -o "/tmp/usb.map")
  if [ $? -ne 0 -o ${STATUS} -ne 200 ]; then
    echo "usb.ids download error!"
  else
    [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
    cp -pf "/tmp/usb.map" "${FILE}"
  fi
fi

# ca-certificates.crt
FILE="/etc/ssl/certs/ca-certificates.crt"
if [ -f "${FILE}" ]; then
  STATUS=$(curl -kL -w "%{http_code}" "https://curl.se/ca/cacert.pem" -o "/tmp/cacert.pem")
  if [ $? -ne 0 -o ${STATUS} -ne 200 ]; then
    echo "ca-certificates.crt download error!"
  else
    [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"
    cp -pf "/tmp/cacert.pem" "${FILE}"
  fi
fi

exit 0