#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "patches" ]; then
  echo "Installing addon sortnetif - ${1}"

  ETHLIST=""
  for F in $(LC_ALL=C printf '%s\n' /sys/class/net/eth* | sort -V); do
    [ ! -e "${F}" ] && continue
    ETH="$(basename "${F}")"
    MAC="$(cat "/sys/class/net/${ETH}/address" 2>/dev/null | sed 's/://g; s/.*/\L&/')"
    BUS="$(ethtool -i "${ETH}" 2>/dev/null | grep "bus-info" | cut -d' ' -f2)"
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done
  ETHLISTTMPM=""
  ETHLISTTMPB="$(printf "%b" "${ETHLIST}" | sort -V)"
  # The MAC list comes from the cmdline, which the loader writes on every boot,
  # so a config change takes effect on the next boot with no rebuild. ${2} is
  # still honoured as a fallback for ramdisks built before that was wired up.
  MACLIST="$(sed -n 's/.*sortnetif=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)"
  [ -z "${MACLIST}" ] && MACLIST="${2}"
  if [ -n "${MACLIST}" ]; then
    MACS="$(echo "${MACLIST}" | sed 's/://g; s/,/ /g; s/.*/\L&/')"
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