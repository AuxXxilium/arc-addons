#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

HDD_BAY_LIST=(RACK_0_Bay RACK_2_Bay RACK_4_Bay RACK_8_Bay RACK_10_Bay RACK_12_Bay RACK_12_Bay_2 RACK_16_Bay RACK_20_Bay RACK_24_Bay RACK_60_Bay
  TOWER_1_Bay TOWER_2_Bay TOWER_4_Bay TOWER_4_Bay_J TOWER_4_Bay_S TOWER_5_Bay TOWER_6_Bay TOWER_8_Bay TOWER_12_Bay)

_UNIQUE="$(/usr/bin/get_key_value /etc.defaults/synoinfo.conf unique)"
_BUILD="$(/usr/bin/get_key_value /etc.defaults/VERSION buildnumber)"
_ARCPANEL="$(/usr/bin/cat /usr/arc/storagepanel.conf 2>/dev/null)"

if [ ${_BUILD:-64570} -gt 64570 ]; then
  FILE_JS="/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js"
else
  FILE_JS="/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"
fi
FILE_GZ="${FILE_JS}.gz"
[ -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

if [ ! -f "${FILE_GZ}" ]; then
  echo "${FILE_GZ} file does not exist"
  exit 0
fi

if [ "${1}" = "-r" ]; then
  if [ -f "${FILE_GZ}.bak" ]; then
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  fi
  rm -f /usr/arc/storagepanel.conf 2>/dev/null
  exit 0
fi

if [ -f "/run/model.dtb" ]; then
  IDX="$(grep -ao "internal_slot@" "/run/model.dtb" | wc -w)"
else
  IDX="$(synodisk --enum -t internal 2>/dev/null | grep "Disk id:" | cut -d: -f2 | sort -n | tail -n1 | xargs)"
fi
while [ ${IDX:-0} -le 60 ]; do
  for i in "${HDD_BAY_LIST[@]}"; do
    echo "${i}" | grep -q "_${IDX:-0}_" && HDD_BAY="${i}" && break 2
  done
  IDX=$((${IDX:-0} + 1))
done
HDD_BAY="${HDD_BAY:-"RACK_60_Bay"}"

if [ -f "/run/model.dtb" ]; then
  IDX="$(grep -ao "nvme_slot@" "/run/model.dtb" | wc -w)"
else
  IDX="$(synodisk --enum -t cache 2>/dev/null | grep "Disk id:" | cut -d: -f2 | sort -n | tail -n1 | xargs)"
fi
[ "${IDX:-0}" -le 8 ] && SSD_BAY="1X${IDX:-0}" || SSD_BAY="$((${IDX:-0} / 8 + 1))X8"

if [ -n "${_ARCPANEL}" ]; then
  ARCPANEL_HDD_BAY="${_ARCPANEL%-*}"
  ARCPANEL_SSD_BAY="${_ARCPANEL#*-}"

  # Extract numeric values for comparison
  ARCPANEL_HDD_COUNT=$(echo "${ARCPANEL_HDD_BAY}" | grep -o '[0-9]\+' | tail -n1)
  HDD_BAY_COUNT=$(echo "${HDD_BAY}" | grep -o '[0-9]\+' | tail -n1)

  ARCPANEL_SSD_ROW=$(echo "${ARCPANEL_SSD_BAY}" | cut -d'X' -f1)
  ARCPANEL_SSD_COL=$(echo "${ARCPANEL_SSD_BAY}" | cut -d'X' -f2)
  SSD_BAY_ROW=$(echo "${SSD_BAY}" | cut -d'X' -f1)
  SSD_BAY_COL=$(echo "${SSD_BAY}" | cut -d'X' -f2)

  # Compare HDD_BAY values
  if [ "${HDD_BAY_COUNT:-0}" -gt "${ARCPANEL_HDD_COUNT:-0}" ]; then
    echo "Using HDD_BAY (${HDD_BAY}) instead of preset HDD_BAY (${ARCPANEL_HDD_BAY})"
  else
    HDD_BAY="${ARCPANEL_HDD_BAY}"
  fi

  # Compare SSD_BAY values
  if [ "${SSD_BAY_ROW:-0}" -gt "${ARCPANEL_SSD_ROW:-0}" ] || [ "${SSD_BAY_COL:-0}" -gt "${ARCPANEL_SSD_COL:-0}" ]; then
    echo "Using SSD_BAY (${SSD_BAY}) instead of preset SSD_BAY (${ARCPANEL_SSD_BAY})"
  else
    SSD_BAY="${ARCPANEL_SSD_BAY}"
  fi
fi

[ ! -f "${FILE_GZ}.bak" ] && cp -pf "${FILE_GZ}" "${FILE_GZ}.bak"

gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
echo "storagepanel set to ${HDD_BAY} ${SSD_BAY}"
OLD="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:[0-9]\+,colCnt:[0-9]\+,xGap:6,yGap:6}\]},"
NEW="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:${SSD_BAY%%X*},colCnt:${SSD_BAY##*X},xGap:6,yGap:6}\]},"
sed -i "s/\"${_UNIQUE}\",//g; s/,\"${_UNIQUE}\"//g; s/${HDD_BAY}:\[\"/${HDD_BAY}:\[\"${_UNIQUE}\",\"/g; s/M2X1:\[\"/M2X1:\[\"${_UNIQUE}\",\"/g; s/${OLD}/${NEW}/g" "${FILE_JS}"
if [ -f "/usr/lib/systemd/system/nvmesystem.service" ] || [ -f "/usr/lib/systemd/system/nvmevolume.service" ]; then
  # 64570
  sed -i "s/e.portType||e.isCacheTray()/e.portType||false/g" "${FILE_JS}"                                    # [42962,?)
  sed -i 's/("normal"!==this.portType)/("normal"!==this.portType\&\&"cache"!==this.portType)/g' "${FILE_JS}" # [64570,?)
  # 42218
  sed -i "s/\!u.isCacheTray()/(\!u.isCacheTray()||true)/g" "${FILE_JS}"                                            # [42218,42962)
  sed -i 's/t="normal"!==this.portType/t="normal"!==this.portType\&\&"cache"!==this.portType/g' "${FILE_JS}"       # [42218,64570)
  sed -i 's/return"normal"===this.portType/return"normal"===this.portType||"cache"===this.portType/g' "${FILE_JS}" # [42218,64570)
fi
gzip -c "${FILE_JS}" >"${FILE_GZ}"

[[ -n "${HDD_BAY}" && -n "${SSD_BAY}" ]] && echo "${HDD_BAY}-${SSD_BAY}" > /usr/arc/storagepanel.conf

exit 0