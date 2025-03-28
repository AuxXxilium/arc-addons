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
if [ -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ]; then
  gzip -c "${FILE_JS}" >"${FILE_GZ}"
fi

if [ ! -f "${FILE_GZ}" ]; then
  echo "${FILE_GZ} file does not exist"
  exit 0
fi

if [ "${1}" = "-r" ]; then
  if [ -f "${FILE_GZ}.bak" ]; then
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  fi
  exit
fi

[ ! -f "${FILE_GZ}.bak" ] && cp -pf "${FILE_GZ}" "${FILE_GZ}.bak"

gzip -dc "${FILE_GZ}" >"${FILE_JS}"
# 64570
sed -i "s/e.portType||e.isCacheTray()/e.portType||false/g" "${FILE_JS}" # [42962,?)
sed -i 's/notSupportM2Pool_addOnCard:this.T("disk_info","disk_reason_m2_add_on_card"),//g' "${FILE_JS}" # [64570,?)
sed -i 's/},{isConditionInvalid:0<this.pciSlot,invalidReason:"notSupportM2Pool_addOnCard"//g' "${FILE_JS}" # [64570,?)
# 42218
sed -i "s/\!u.isCacheTray()/(\!u.isCacheTray()||true)/g" "${FILE_JS}" # [42218,42962)
sed -i 's/t="normal"!==this.portType/t="normal"!==this.portType\&\&"cache"!==this.portType/g' "${FILE_JS}" # [42218,64570)
sed -i 's/return"normal"===this.portType/return"normal"===this.portType||"cache"===this.portType/g' "${FILE_JS}" # [42218,64570)
gzip -c "${FILE_JS}" >"${FILE_GZ}"

# M.2 drives in M2 adaptor card do not officially support storage pools
for F in /run/synostorage/disks/nvme*/m2_pool_support; do
  [ ! -e "${F}" ] && continue
  echo -n 1 >"${F}"
done

exit 0