#!/bin/sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# /bin/sh, not /usr/bin/env: junior's web server starts this by its shebang,
# and junior's ramdisk is not a full DSM. Its own CGIs use /bin/sh.
# A CGI's PATH can lack /sbin, where lsmod, modprobe and reboot live.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/syno/sbin:/usr/syno/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

if [ ! -f /usr/bin/loader-reboot.sh ]; then
  echo '{"success": false, "error": "loader-reboot.sh not found"}'
  exit 0
fi

# Through sh rather than its own shebang, for the same reason. On success it
# reboots and this response may never arrive; it returns only when it could
# not set the boot entry or the reboot did not take.
if sh /usr/bin/loader-reboot.sh config; then
  echo '{"success": true}'
else
  echo '{"success": false}'
fi
