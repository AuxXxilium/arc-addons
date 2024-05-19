#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

_BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"

if [ ${_BUILD:-64570} -gt 64570 ]; then
  FILE_JS="/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js"
else
  FILE_JS="/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"
fi
FILE_GZ="${FILE_JS}.gz"
[ -f "${FILE_JS}" -a ! -f "${FILE_GZ}" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

[ ! -f "${FILE_GZ}" ] && echo "${FILE_GZ} file does not exist" && exit 0

if [ "${1}" = "-r" ]; then
  if [ -f "${FILE_GZ}.bak" ]; then
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  fi
  exit
fi

[ ! -f "${FILE_GZ}.bak" ] && cp -f "${FILE_GZ}" "${FILE_GZ}.bak"

gzip -dc "${FILE_GZ}" >"${FILE_JS}"
sed -i "s/e.portType||e.isCacheTray()/e.portType||false/" "${FILE_JS}"
gzip -c "${FILE_JS}" >"${FILE_GZ}"

exit 0