#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

HDD_BAY_LIST=(RACK_0_Bay RACK_2_Bay RACK_4_Bay RACK_8_Bay RACK_10_Bay RACK_12_Bay RACK_12_Bay_2 RACK_16_Bay RACK_20_Bay RACK_24_Bay RACK_60_Bay
  TOWER_1_Bay TOWER_2_Bay TOWER_4_Bay TOWER_4_Bay_J TOWER_4_Bay_S TOWER_5_Bay TOWER_6_Bay TOWER_8_Bay TOWER_12_Bay)

_hdd_bay_to_count() {
  echo "${1}" | sed -n 's/^[A-Z]\+_\([0-9]\+\)_Bay\(_[0-9]\+\)\?$/\1/p'
}

_ssd_bay_to_count() {
  _rows="${1%%X*}"
  _cols="${1##*X}"
  [ -n "${_rows}" ] && [ -n "${_cols}" ] && echo $((_rows * _cols)) || echo 0
}

_auto_hdd_bay() {
  if [ -f "/run/model.dtb" ]; then
    IDX="$(grep -ao "internal_slot@" "/run/model.dtb" | wc -w)"
  else
    IDX="$(synodisk --enum -t internal 2>/dev/null | grep "Disk id:" | cut -d: -f2 | sort -n | tail -n1 | xargs)"
  fi

  while [ ${IDX:-0} -le 60 ]; do
    for i in "${HDD_BAY_LIST[@]}"; do
      echo "${i}" | grep -q "_${IDX:-0}_" && {
        echo "${i}"
        return
      }
    done
    IDX=$((${IDX:-0} + 1))
  done

  echo "RACK_60_Bay"
}

_auto_ssd_bay() {
  if [ -f "/run/model.dtb" ]; then
    IDX="$(grep -ao "nvme_slot@" "/run/model.dtb" | wc -w)"
  else
    IDX="$(synodisk --enum -t cache 2>/dev/null | grep "Disk id:" | cut -d: -f2 | sort -n | tail -n1 | xargs)"
  fi

  [ "${IDX:-0}" -le 8 ] && echo "1X${IDX:-0}" || echo "$((IDX / 8 + 1))X8"
}

if [ "${1}" = "-h" ]; then
  echo "Use: ${0} [HDD_BAY [SSD_BAY]]"
  echo "  HDD_BAY: ${HDD_BAY_LIST[*]}"
  echo "  SSD_BAY: (row)X(column)"
  echo "  -r: restore"
  echo "  -h: help"
  echo "  e.g.:"
  echo "    ${0}                  - auto"
  echo "    ${0} RACK_24_Bay      - HDD_BAY set to RACK_24_Bay, SSD_BAY auto"
  echo "    ${0} RACK_24_Bay 1X8  - HDD_BAY set to RACK_24_Bay, SSD_BAY set to 1X8"
  echo "    ${0} RACK_60_Bay 2X8  - HDD_BAY set to RACK_60_Bay, SSD_BAY set to 2X8"
  echo "    ${0} -r               - restore"
  echo "    ${0} -h               - help"
  exit
fi

_UNIQUE="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique)"
_BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"
_ARCPANEL="$(/bin/cat /usr/arc/storagepanel.conf 2>/dev/null)"

if [ ${_BUILD:-64570} -gt 64570 ]; then
  FILE_JS="/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js"
else
  FILE_JS="/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"
fi
FILE_GZ="${FILE_JS}.gz"
[ -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

if [ ! -f "${FILE_GZ}" ]; then
  echo "Waiting for ${FILE_GZ}..."
  WAIT=0
  while [ ! -f "${FILE_GZ}" ] && [ ${WAIT} -lt 60 ]; do
    sleep 5
    WAIT=$((WAIT + 5))
    [ -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"
  done
  if [ ! -f "${FILE_GZ}" ]; then
    echo "${FILE_GZ} file does not exist"
    exit 0
  fi
fi

if [ "${1}" = "-r" ]; then
  if [ -f "${FILE_GZ}.bak" ]; then
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  fi
  rm -f /usr/arc/storagepanel.conf 2>/dev/null
  SM_KEY="sm_machine_img_config_name"
  synosetkeyvalue /etc.defaults/synoinfo.conf "${SM_KEY}" "$(synogetkeyvalue /etc/synoinfo.conf "${SM_KEY}")"
  exit
fi

# Parse command line arguments
[ -n "${1}" ] && HDD_BAY="$(echo "${HDD_BAY_LIST[@]}" | grep -iwo "${1}")" || HDD_BAY=""
if [ -n "${1}" ] && [ -z "${HDD_BAY}" ]; then
  echo "parameter 1 error"
fi

SSD_BAY="$(echo "${2^^}" | sed 's/*/X/')"
if [ -n "${SSD_BAY}" ] && [ -z "$(echo "${SSD_BAY}" | sed -n '/^[0-9]\{1,2\}X[0-9]\{1,2\}$/p')" ]; then
  echo "parameter 2 error"
  SSD_BAY=""
fi

SAVED_HDD_BAY="${_ARCPANEL%-*}"
SAVED_SSD_BAY="${_ARCPANEL#*-}"
if [ -n "${_ARCPANEL}" ] && [ "${SAVED_HDD_BAY}" != "${_ARCPANEL}" ] && [ "${SAVED_SSD_BAY}" != "${_ARCPANEL}" ]; then
  echo "Using saved configuration: ${_ARCPANEL}"
else
  SAVED_HDD_BAY=""
  SAVED_SSD_BAY=""
fi

AUTO_HDD_BAY="$(_auto_hdd_bay)"
AUTO_SSD_BAY="$(_auto_ssd_bay)"

if [ -z "${HDD_BAY}" ]; then
  SAVED_HDD_COUNT="$(_hdd_bay_to_count "${SAVED_HDD_BAY}")"
  AUTO_HDD_COUNT="$(_hdd_bay_to_count "${AUTO_HDD_BAY}")"
  if [ -n "${SAVED_HDD_COUNT}" ] && [ "${SAVED_HDD_COUNT}" -ge "${AUTO_HDD_COUNT:-0}" ]; then
    HDD_BAY="${SAVED_HDD_BAY}"
  else
    HDD_BAY="${AUTO_HDD_BAY}"
  fi
fi

if [ -z "${SSD_BAY}" ]; then
  SAVED_SSD_COUNT="$(_ssd_bay_to_count "${SAVED_SSD_BAY}")"
  AUTO_SSD_COUNT="$(_ssd_bay_to_count "${AUTO_SSD_BAY}")"
  if echo "${SAVED_SSD_BAY}" | grep -Eq '^[0-9]{1,2}X[0-9]{1,2}$' && [ "${SAVED_SSD_COUNT}" -ge "${AUTO_SSD_COUNT:-0}" ]; then
    SSD_BAY="${SAVED_SSD_BAY}"
  else
    SSD_BAY="${AUTO_SSD_BAY}"
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

# Save configuration for persistence across reboots
echo "${HDD_BAY}-${SSD_BAY}" > /usr/arc/storagepanel.conf
# Backup and clear DSM's cached panel name to force use of patched JS (DSM 7.3)
SM_KEY="sm_machine_img_config_name"
[ -z "$(synogetkeyvalue /etc/synoinfo.conf "${SM_KEY}")" ] && synosetkeyvalue /etc/synoinfo.conf "${SM_KEY}" "$(synogetkeyvalue /etc.defaults/synoinfo.conf "${SM_KEY}")"
synosetkeyvalue /etc.defaults/synoinfo.conf "${SM_KEY}" ""

exit 0