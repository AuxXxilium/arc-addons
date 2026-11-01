#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Sort key of interface ${1}, as the loader's _netif_key: the PCI address its
# device sits on, as decimals (bus addresses are hex, which sort -V puts wrong:
# 0000:1b before 0000:13), a virtio NIC by the virtio-pci device it is behind.
# A USB NIC sorts after every PCI one, by its path, and one with no device last.
_netif_key() {
  P="$(readlink -f "/sys/class/net/${1}/device" 2>/dev/null)"
  [ -z "${P}" ] && echo "3 ${1}" && return
  case "${P}" in */usb*) echo "2 ${P}" && return ;; esac
  A="$(echo "${P}" | tr '/' '\n' | grep -E '^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$' | tail -1)"
  [ -z "${A}" ] && echo "2 ${P}" && return
  D="${A%%:*}"
  A="${A#*:}"
  B="${A%%:*}"
  A="${A#*:}"
  printf '1 %05d %03d %03d %d\n' "$((0x${D}))" "$((0x${B}))" "$((0x${A%.*}))" "$((0x${A#*.}))"
}

if [ "${1}" = "patches" ]; then
  echo "Installing addon sortnetif - ${1}"

  # One line per NIC, "<key> <name> <mac>", in the loader's order: by key,
  # then by name.
  ETHLIST=""
  for F in /sys/class/net/eth*; do
    [ ! -e "${F}" ] && continue
    ETH="$(basename "${F}")"
    MAC="$(cat "/sys/class/net/${ETH}/address" 2>/dev/null | sed 's/://g; s/.*/\L&/')"
    ETHLIST="${ETHLIST}$(_netif_key "${ETH}") ${ETH} ${MAC:--}
"
  done
  ETHLIST="$(printf '%s' "${ETHLIST}" | LC_ALL=C sort)"
  # The MAC list comes from the cmdline, which the loader writes on every boot,
  # so a config change takes effect on the next boot with no rebuild. ${2} is
  # still honoured as a fallback for ramdisks built before that was wired up.
  # The pinned MACs go first, in list order, matched on the MAC column only.
  MACLIST="$(sed -n 's/.*sortnetif=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)"
  [ -z "${MACLIST}" ] && MACLIST="${2}"
  ETHLISTM=""
  for MACX in $(echo "${MACLIST}" | sed 's/://g; s/,/ /g; s/.*/\L&/'); do
    ETHLISTM="${ETHLISTM}$(echo "${ETHLIST}" | awk -v m="${MACX}" '$NF == m')
"
    ETHLIST="$(echo "${ETHLIST}" | awk -v m="${MACX}" '$NF != m')"
  done
  ETHLIST="$(printf '%s\n%s\n' "${ETHLISTM}" "${ETHLIST}" | grep -v '^$')"
  ORDER="$(echo "${ETHLIST}" | awk '{print $(NF - 1)}')"

  echo "${ETHLIST}"
  SORTED=true
  I=0
  for N in ${ORDER}; do
    [ "${N}" = "eth${I}" ] || SORTED=false
    I=$((I + 1))
  done
  # sort
  if [ "${SORTED}" = "false" ]; then
    /etc/rc.network stop
    # Through temporary names: eth0 cannot become eth1 while eth1 is there.
    # The kernel refuses to rename an interface that is up, and rc.network
    # stop does not take every link down.
    I=0
    for N in ${ORDER}; do
      ip link set dev "${N}" down
      ip link set dev "${N}" name "tmp${I}"
      I=$((I + 1))
    done
    I=0
    for N in ${ORDER}; do
      ip link set dev "tmp${I}" name "eth${I}"
      I=$((I + 1))
    done
    /etc/rc.network start
  fi
fi
