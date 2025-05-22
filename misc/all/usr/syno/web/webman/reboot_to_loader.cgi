#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

if [ -f /usr/bin/loader-reboot.sh ]; then
  /usr/bin/loader-reboot.sh config
  echo '{"success": true}'
else
  echo '{"success": false}'
fi