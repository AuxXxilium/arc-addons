#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon sortnetif - ${1}"

  ETHLIST=""
  ETHX="$(ls /sys/class/net/ 2>/dev/null | grep eth)" # real network cards list
  for ETH in ${ETHX}; do
    BUS="$(ethtool -i ${ETH} 2>/dev/null | grep bus-info | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${ETH}\n"
  done
  ETHLISTTMPB="$(echo -e "${ETHLIST}" | sort)"
  ETHLIST="$(echo -e "${ETHLISTTMPB}" | grep -v '^$')"
  ETHSEQ="$(echo -e "${ETHLIST}" | awk '{print $2}' | sed 's/eth//g')"
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
    /etc/rc.network restart
  fi
}

case "${1}" in
  patches)
    install_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0