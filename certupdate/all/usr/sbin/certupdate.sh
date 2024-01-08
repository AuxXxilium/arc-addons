#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#

# ca-certificates.crt
FILE="/etc/ssl/certs/ca-certificates.crt"
if [ -f "${FILE}" ]; then
  STATUS=$(curl -kL -w "%{http_code}" "https://curl.se/ca/cacert.pem" -o "/tmp/cacert.pem")
  if [ $? -ne 0 -o ${STATUS} -ne 200 ]; then
    echo "ca-certificates.crt download error!"
  else
    [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"
    cp -f "/tmp/cacert.pem" "${FILE}"
  fi
fi

exit 0