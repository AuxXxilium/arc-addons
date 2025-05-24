#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon sortnetif - ${1}"

  ETHLIST=""
  for F in /sys/class/net/eth*; do
    [ ! -e "${F}" ] && continue
    ETH="$(basename "${F}")"
    MAC="$(cat "/sys/class/net/${ETH}/address" 2>/dev/null | sed 's/://g; s/.*/\L&/')"
    BUS="$(ethtool -i "${ETH}" 2>/dev/null | grep "bus-info" | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done
  ETHLISTTMPM=""
  ETHLISTTMPB="$(printf "%b" "${ETHLIST}" | sort)"
  if [ -n "${2}" ]; then
    MACS="$(echo "${2}" | sed 's/://g; s/,/ /g; s/.*/\L&/')"
    for MACX in ${MACS}; do
      ETHLISTTMPM="${ETHLISTTMPM}$(printf "%b" "${ETHLISTTMPB}" | grep "${MACX}")\n"
      ETHLISTTMPB="$(printf "%b" "${ETHLISTTMPB}" | grep -v "${MACX}")\n"
    done
  fi
  ETHLIST="$(printf "%b" "${ETHLISTTMPM}${ETHLISTTMPB}" | grep -v '^$')"
  ETHSEQ="$(printf "%b" "${ETHLIST}" | awk '{print $3}' | sed 's/eth//g')"
  ETHNUM="$(echo "${ETHSEQ}" | wc -l)" # 'wc -l' is incompatible with 'printf "%b" "${ETHLIST}"'

  printf "%b\n" "${ETHLIST}"
  # sort
  if [ ! "${ETHSEQ}" = "$(seq 0 $((${ETHNUM:-0} - 1)))" ]; then
    /etc/rc.network stop
    for i in $(seq 0 $((${ETHNUM:-0} - 1))); do
      ip link set dev "eth${i}" name "tmp${i}"
    done
    I=0
    for i in ${ETHSEQ}; do
      ip link set dev "tmp${i}" name "eth${I}"
      I=$((I + 1))
    done
    /etc/rc.network start
  fi
fi
exit 0