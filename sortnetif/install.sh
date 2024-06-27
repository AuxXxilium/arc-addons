#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Get values in synoinfo.conf K=V file
# 1 - key
function _get_conf_kv() {
  grep "${1}=" /etc/synoinfo.conf 2>/dev/null | sed "s|^${1}=\"\(.*\)\"$|\1|g"
}

# Replace/add values in synoinfo.conf K=V file
# Args: $1 rd|hd, $2 key, $3 val
function _set_conf_kv() {
  local ROOT
  local FILE
  [ "$1" = "rd" ] && ROOT="" || ROOT="/tmpRoot"
  for SD in etc etc.defaults; do
    FILE="${ROOT}/${SD}/synoinfo.conf"
    # Replace
    if grep -q "^$2=" ${FILE}; then
      sed -i ${FILE} -e "s\"^$2=.*\"$2=\\\"$3\\\"\""
    else
      # Add if doesn't exist
      echo "$2=\"$3\"" >>${FILE}
    fi
  done
}

if [ "${1}" = "patches" ]; then
  echo "Installing addon sortnetif - ${1}"

  ETHLIST=""
  ETHX="$(ls /sys/class/net/ 2>/dev/null | grep eth)" # real network cards list
  for ETH in ${ETHX}; do
    MAC="$(cat /sys/class/net/${ETH}/address 2>/dev/null | sed 's/://g' | tr '[:upper:]' '[:lower:]')"
    BUS="$(ethtool -i ${ETH} 2>/dev/null | grep bus-info | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done
  ETHLISTTMPM=""
  ETHLISTTMPB="$(echo -e "${ETHLIST}" | sort)"
  if [ -n "${2}" ]; then
    MACS="$(echo "${2}" | sed 's/://g' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')"
    for MACX in ${MACS}; do
      ETHLISTTMPM="${ETHLISTTMPM}$(echo -e "${ETHLISTTMPB}" | grep "${MACX}")\n"
      ETHLISTTMPB="$(echo -e "${ETHLISTTMPB}" | grep -v "${MACX}")\n"
    done
  fi
  ETHLIST="$(echo -e "${ETHLISTTMPM}${ETHLISTTMPB}" | grep -v '^$')"
  ETHSEQ="$(echo -e "${ETHLIST}" | awk '{print $3}' | sed 's/eth//g' | tr '\n' ' ')"
  ETHNUM="$(echo -e "${ETHLIST}" | wc -l)"

  _set_conf_kv rd netif_seq "${ETHSEQ}"

  if [ -x /usr/syno/bin/synonetseqadj ]; then
    /usr/syno/bin/synonetseqadj
  else
    echo "sortnetif error: synonetseqadj not found!"
  fi

elif [ "${1}" = "late" ]; then
  echo "Installing addon sortnetif - ${1}"

  ETHSEQ="$(_get_conf_kv netif_seq)"
  _set_conf_kv hd netif_seq "${ETHSEQ}"
fi
