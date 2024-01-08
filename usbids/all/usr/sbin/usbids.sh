#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#

# usb.map
FILE="/usr/syno/etc.defaults/usb.map"
STATUS=$(curl -kL -w "%{http_code}" "http://www.linux-usb.org/usb.ids" -o "${FILE}.ids")
if [ $? -ne 0 -o ${STATUS} -ne 200 ]; then
  echo "usb.ids download error!"
else
  [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"
  mv -f "${FILE}.ids" "${FILE}"
  chmod a+rx "${FILE}"
fi
cp -f "${FILE}" "${FILE/\.defaults/}"

exit 0