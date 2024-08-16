#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon sortnetif - ${1}"

  ETHLIST=""
  ETHX="$(ls /sys/class/net/ 2>/dev/null | grep eth)" # real network cards list
  for ETH in ${ETHX}; do
    MAC="$(cat /sys/class/net/${ETH}/address 2>/dev/null | sed 's/://g; s/.*/\L&/')"
    BUS="$(ethtool -i ${ETH} 2>/dev/null | grep bus-info | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done
  ETHLISTTMPM=""
  ETHLISTTMPB="$(echo -e "${ETHLIST}" | sort)"
  if [ -n "${2}" ]; then
    MACS="$(echo "${2}" | sed 's/://g; s/,/ /g; s/.*/\L&/')"
    for MACX in ${MACS}; do
      ETHLISTTMPM="${ETHLISTTMPM}$(echo -e "${ETHLISTTMPB}" | grep "${MACX}")\n"
      ETHLISTTMPB="$(echo -e "${ETHLISTTMPB}" | grep -v "${MACX}")\n"
    done
  fi
  ETHLIST="$(echo -e "${ETHLISTTMPM}${ETHLISTTMPB}" | grep -v '^$')"
  ETHSEQ="$(echo -e "${ETHLIST}" | awk '{print $3}' | sed 's/eth//g')"
  ETHNUM="$(echo -e "${ETHLIST}" | wc -l)"

  echo "${ETHSEQ}"
  # sort
  if [ ! "${ETHSEQ}" = "$(seq 0 $((${ETHNUM:0} - 1)))" ]; then
    /etc/rc.network stop
    for i in $(seq 0 $((${ETHNUM:0} - 1))); do
      ip link set dev eth${i} name tmp${i}
    done
    I=0
    for i in ${ETHSEQ}; do
      ip link set dev tmp${i} name eth${I}
      I=$((${I} + 1))
    done
    /etc/rc.network start
  fi
fi
