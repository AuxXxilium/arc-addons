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
    MAC="$(cat /sys/class/net/${ETH}/address 2>/dev/null | sed 's/://g' | tr '[:upper:]' '[:lower:]')"
    BUS="$(ethtool -i ${ETH} 2>/dev/null | grep bus-info | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done

  if [ -n "${2}" ]; then
    MACS="$(echo "${2}" | sed 's/://g' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')"
    ETHLISTTMPC=""
    ETHLISTTMPF=""

    for MACX in ${MACS}; do
      ETHLISTTMPC="${ETHLISTTMPC}$(echo -e "${ETHLIST}" | grep "${MACX}")\n"
    done

    while read -r BUS MAC ETH; do
      [ -z "${MAC}" ] && continue
      if echo "${MACS}" | grep -q "${MAC}"; then continue; fi
      ETHLISTTMPF="${ETHLISTTMPF}${BUS} ${MAC} ${ETH}\n"
    done <<EOF
$(echo -e ${ETHLIST} | sort)
EOF
    ETHLIST="${ETHLISTTMPC}${ETHLISTTMPF}"
  else
    ETHLIST="$(echo -e "${ETHLIST}" | sort)"
  fi
  ETHLIST="$(echo -e "${ETHLIST}" | grep -v '^$')"

  echo -e "${ETHLIST}" >/tmp/ethlist
  cat /tmp/ethlist

  # sort
  IDX=0
  while true; do
    cat /tmp/ethlist
    [ ${IDX} -ge $(wc -l </tmp/ethlist) ] && break
    ETH="$(cat /tmp/ethlist | sed -n "$((${IDX} + 1))p" | cut -d' ' -f3)"
    echo "ETH: ${ETH}"
    if [ -n "${ETH}" ] && [ ! "${ETH}" = "eth${IDX}" ]; then
      echo "change ${ETH} <=> eth${IDX}"
      ip link set dev eth${IDX} down
      ip link set dev ${ETH} down
      sleep 1
      ip link set dev eth${IDX} name ethN
      ip link set dev ${ETH} name eth${IDX}
      ip link set dev ethN name ${ETH}
      sleep 1
      ip link set dev eth${IDX} up
      ip link set dev ${ETH} up
      sleep 1
      sed -i "s/eth${IDX}/ethN/" /tmp/ethlist
      sed -i "s/${ETH}/eth${IDX}/" /tmp/ethlist
      sed -i "s/ethN/${ETH}/" /tmp/ethlist
      sleep 1
    fi
    IDX=$((${IDX} + 1))
  done

  rm -f /tmp/ethlist
fi