#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  # $2 ?
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
  # $3 ?
  #  (row)X(column)    # default: 1X8

  HDD_BAY="${2-RACK_24_Bay}"
  SSD_BAY="${3:-1X8}"

  echo "storagepanel setting ${HDD_BAY} ${SSD_BAY}"

  _UNIQUE="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique)"
  _BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"

  if [ ${_BUILD} -gt 64570 ]; then
    FILE_JS="/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js"
  else
    FILE_JS="/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"
  fi
  FILE_GZ="${FILE_JS}.gz"

  [ ! -f "${FILE_JS}" -a ! -f "${FILE_GZ}" ] && echo "${FILE_JS} file does not exist" && exit 0

  HDD_BAY_LIST=(RACK_0_Bay RACK_2_Bay RACK_4_Bay RACK_8_Bay RACK_10_Bay RACK_12_Bay RACK_12_Bay_2 RACK_16_Bay RACK_20_Bay RACK_24_Bay RACK_60_Bay
    TOWER_1_Bay TOWER_2_Bay TOWER_4_Bay TOWER_4_Bay_J TOWER_4_Bay_S TOWER_5_Bay TOWER_6_Bay TOWER_8_Bay TOWER_12_Bay)

  if [ "${HDD_BAY}" = "-r" ]; then
    if [ -f "${FILE_GZ}.bak" ]; then
      rm -f "${FILE_JS}" "${FILE_GZ}"
      mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
      gzip -dc "${FILE_GZ}" >"${FILE_JS}"
      chmod a+r "${FILE_JS}" "${FILE_GZ}"
    elif [ -f "${FILE_JS}.bak" ]; then
      mv -f "${FILE_JS}.bak" "${FILE_JS}"
      chmod a+r "${FILE_JS}"
    fi
    exit
  fi

  if ! echo "${HDD_BAY_LIST[@]}" | grep -wq "${HDD_BAY}"; then
    echo "parameter 1 error"
    exit
  fi

  if [ -z "$(echo ${SSD_BAY} | sed -n '/^[0-9]\{1,2\}X[0-9]\{1,2\}$/p')" ]; then
    echo "parameter 2 error"
    exit
  fi

  if [ -f "${FILE_GZ}" ]; then
    [ ! -f "${FILE_GZ}.bak" ] && cp -f "${FILE_GZ}" "${FILE_GZ}.bak" && chmod a+r "${FILE_GZ}.bak"
  else
    [ ! -f "${FILE_JS}.bak" ] && cp -f "${FILE_JS}" "${FILE_JS}.bak" && chmod a+r "${FILE_JS}.bak"
  fi

  rm -f "${FILE_JS}"
  if [ -f "${FILE_GZ}.bak" ]; then
    gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
  else
    cp -f "${FILE_JS}.bak" "${FILE_JS}"
  fi
  echo "storagepanel set to ${HDD_BAY} ${SSD_BAY}"
  OLD="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:1,colCnt:2,xGap:6,yGap:6}\]},"
  NEW="driveShape:\"Mdot2-shape\",major:\"row\",rowDir:\"UD\",colDir:\"LR\",driveSection:\[{top:14,left:18,rowCnt:${SSD_BAY%%X*},colCnt:${SSD_BAY##*X},xGap:6,yGap:6}\]},"
  sed -i "s/\"${_UNIQUE}\",//g; s/,\"${_UNIQUE}\"//g; s/${HDD_BAY}:\[\"/${HDD_BAY}:\[\"${_UNIQUE}\",\"/g; s/M2X1:\[\"/M2X1:\[\"${_UNIQUE}\",\"/g; s/${OLD}/${NEW}/g" "${FILE_JS}"
  chmod a+r "${FILE_JS}"
  if [ -f "${FILE_GZ}.bak" ]; then
    gzip -c "${FILE_JS}" >"${FILE_GZ}"
    chmod a+r "${FILE_GZ}"
  fi

fi
