#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# $1 ?
#  RACK_0_Bay
#  RACK_2_Bay
#  RACK_4_Bay
#  RACK_8_Bay
#  RACK_10_Bay
#  RACK_12_Bay
#  RACK_12_Bay_2
#  RACK_16_Bay
#  RACK_20_Bay
#  RACK_24_Bay       # default
#  RACK_60_Bay
#  TOWER_1_Bay
#  TOWER_2_Bay
#  TOWER_4_Bay
#  TOWER_4_Bay_J
#  TOWER_4_Bay_S
#  TOWER_5_Bay
#  TOWER_6_Bay
#  TOWER_8_Bay
#  TOWER_12_Bay
#  -r                # restore
# $2 ?
#  (row)X(column)    # default: 1X8

HDD_BAY_LIST=(RACK_0_Bay RACK_2_Bay RACK_4_Bay RACK_8_Bay RACK_10_Bay RACK_12_Bay RACK_12_Bay_2 RACK_16_Bay RACK_20_Bay RACK_24_Bay RACK_60_Bay
  TOWER_1_Bay TOWER_2_Bay TOWER_4_Bay TOWER_4_Bay_J TOWER_4_Bay_S TOWER_5_Bay TOWER_6_Bay TOWER_8_Bay TOWER_12_Bay)
SSD_BAY_LIST=(1X0 1X2 1X4 1X8)

_UNIQUE="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique)"
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

HDD_BAY="${1}"
if [ -n "${1}" ] && ! echo "${HDD_BAY_LIST[@]}" | grep -wq "${1}"; then
  echo "storagepanel: parameter 1 error"
  HDD_BAY=""
fi

SSD_BAY="${2}"
if [ -n "${2}" ] && [ -z "$(echo "${2}" | sed -n '/^[0-9]\{1,2\}X[0-9]\{1,2\}$/p')" ]; then
  echo "storagepanel: parameter 2 error"
  SSD_BAY=""
fi

if [ -z "${HDD_BAY}" ]; then
  IDX="$(echo $(synodisk --enum -t internal 2>/dev/null | grep "Disk id:" | tail -n 1 | cut -d: -f2))"
  IDX=${IDX:-0}
  while [ "${IDX}" -le 60 ]; do
    for i in "${HDD_BAY_LIST[@]}"; do
      echo "${i}" | grep -q "_${IDX}_" && HDD_BAY="${i}" && break 2
    done
    IDX=$((IDX + 1))
  done
  if [ ${IDX} -gt 24 ]
    HDD_BAY=RACK_24_Bay
  fi
  HDD_BAY=${HDD_BAY:-RACK_60_Bay}
fi

if [ -z "${SSD_BAY}" ]; then
  IDX="$(echo $(synodisk --enum -t cache 2>/dev/null | grep "Disk id:" | tail -n 1 | cut -d: -f2))"
  IDX=${IDX:-0}
  while [ "${IDX}" -le 8 ]; do
    for i in "${SSD_BAY_LIST[@]}"; do
      echo "${i}" | grep -q "1X${IDX}" && SSD_BAY="${i}" && break 2
    done
    IDX=$((IDX + 1))
  done
  SSD_BAY=${SSD_BAY:-1X8}
fi

[ ! -f "${FILE_GZ}.bak" ] && cp -f "${FILE_GZ}" "${FILE_GZ}.bak"

gzip -dc "${FILE_GZ}" >"${FILE_JS}"
echo "storagepanel set to ${HDD_BAY} ${SSD_BAY}"
OLD="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:[0-9]\+,colCnt:[0-9]\+,xGap:6,yGap:6}\]},"
NEW="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:${SSD_BAY%%X*},colCnt:${SSD_BAY##*X},xGap:6,yGap:6}\]},"
sed -i "s/\"${_UNIQUE}\",//g; s/,\"${_UNIQUE}\"//g; s/${HDD_BAY}:\[\"/${HDD_BAY}:\[\"${_UNIQUE}\",\"/g; s/M2X1:\[\"/M2X1:\[\"${_UNIQUE}\",\"/g; s/${OLD}/${NEW}/g" "${FILE_JS}"
gzip -c "${FILE_JS}" >"${FILE_GZ}"

exit 0