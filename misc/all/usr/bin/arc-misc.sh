#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# shellcheck disable=SC2034,SC3043

get_section_kv() {
  local file="${1}"
  local section="${2}"
  local key="${3}"
  awk -v section="${section}" -v key="${key}" '
    $0 ~ "^[[:space:]]*\\["section"\\][[:space:]]*$" { in_section=1; next }
    in_section && $0 ~ "^[[:space:]]*\\[" { in_section=0 }
    in_section && $0 ~ "^[[:space:]]*"key"=" {
      sub("^[[:space:]]*"key"=","")
      print
      exit
    }
  ' "${file}"
}

set_section_kv() {
  local file="${1}"
  local section="${2}"
  local key="${3}"
  local value="${4}"

  if [ -z "${file}" ] || [ -z "${section}" ]; then
    echo "Usage: set_section_key_value <file> <section> <key> <value>"
    return 1
  fi

  if ! grep -q "^\[${section}\]" "${file}" 2>/dev/null; then
    echo "[${section}]" >>"${file}"
  fi

  if [ -n "${key}" ]; then
    sed -i "/^\[${section}\]/,/^\[/ {
      /^\[${section}\]/b
      /^\[/b
      s|^[[:space:]]*${key}=.*|\t${key}=${value}|
      t
      \$a	\t${key}=${value}
    }" "${file}"
  fi
}

GCKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SCKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")
GSKV=$([ -x "/usr/syno/bin/get_section_key_value" ] && echo "/usr/syno/bin/get_section_key_value" || echo "get_section_kv")
SSKV=$([ -x "/usr/syno/bin/set_section_key_value" ] && echo "/usr/syno/bin/set_section_key_value" || echo "set_section_kv")

###############################################################################

# packages
if [ ! -f /usr/syno/etc/packages/feeds ]; then
  mkdir -p /usr/syno/etc/packages
  echo '[{"feed":"https://spk7.imnks.com","name":"imnks"},{"feed":"https://packages.synocommunity.com","name":"synocommunity"}]' >/usr/syno/etc/packages/feeds
fi

# network
if grep -q 'network.' /proc/cmdline; then
  printf "" >/etc/sysconfig/network-cmdline.txt
  for I in $(grep -Eo 'network.[0-9a-fA-F:]{12,17}=[^ ]*' /proc/cmdline); do
    MACR="$(echo "${I}" | cut -d. -f2 | cut -d= -f1 | sed 's/://g; s/.*/\L&/')"
    IPRS="$(echo "${I}" | cut -d= -f2)"
    /usr/syno/sbin/synonet --show 2>/dev/null | grep "interface: " | awk '{print $NF}' | while read -r ETH; do
      MACX="$(/usr/syno/sbin/synonet --get_mac_addr "${ETH}" original 2>/dev/null | awk -F'Mac is: ' '{print $2}' | sed 's/://g; s/.*/\L&/')"
      if [ "${MACR}" = "${MACX}" ]; then
        echo "${I}" >/etc/sysconfig/network-cmdline.txt
        echo "Setting IP for ${ETH} to ${IPRS}"
        CF="/etc/sysconfig/network-scripts/ifcfg-${ETH}"
        SF="/etc/iproute2/config/gateway_database"
        ${SCKV} "${CF}" "BOOTPROTO" "static"
        ${SCKV} "${CF}" "ONBOOT" "yes"
        ${SCKV} "${CF}" "IPADDR" "$(echo "${IPRS}" | cut -d/ -f1)"
        ${SCKV} "${CF}" "NETMASK" "$(echo "${IPRS}" | cut -d/ -f2)"
        ${SCKV} "${CF}" "GATEWAY" "$(echo "${IPRS}" | cut -d/ -f3)"
        ${SSKV} "${SF}" "${ETH}" dns "$(echo "${IPRS}" | cut -d/ -f4)"
        ${SSKV} "${SF}" "${ETH}" gateway "$(echo "${IPRS}" | cut -d/ -f3)"
        /etc/rc.network restart "${ETH}" >/dev/null 2>&1
        # [ -n "$(echo "${IPRS}" | cut -d/ -f4)" ] &&  /etc/rc.network_routing "$(echo "${IPRS}" | cut -d/ -f4)" &
      fi
    done
  done
else
  if [ -f "/etc/sysconfig/network-cmdline.txt" ]; then
    for I in $(cat /etc/sysconfig/network-cmdline.txt); do
      MACR="$(echo "${I}" | cut -d. -f2 | cut -d= -f1 | sed 's/://g; s/.*/\L&/')"
      IPRS="$(echo "${I}" | cut -d= -f2)"
      /usr/syno/sbin/synonet --show 2>/dev/null | grep "interface: " | awk '{print $NF}' | while read -r ETH; do
        MACX="$(/usr/syno/sbin/synonet --get_mac_addr "${ETH}" original 2>/dev/null | awk -F'Mac is: ' '{print $2}' | sed 's/://g; s/.*/\L&/')"
        if [ "${MACR}" = "${MACX}" ]; then
          echo "Setting IP for ${ETH} to dhcp"
          CF="/etc/sysconfig/network-scripts/ifcfg-${ETH}"
          SF="/etc/iproute2/config/gateway_database"
          sed -i "s|^BOOTPROTO=.*|BOOTPROTO=dhcp|; s|^ONBOOT=.*|ONBOOT=yes|; s|^IPV6INIT=.*|IPV6INIT=dhcp|; /^IPADDR/d; /NETMASK/d; /GATEWAY/d; /DNS1/d; /DNS2/d" "${CF}"
          ${SSKV} "${SF}" "${ETH}" dns ""
          ${SSKV} "${SF}" "${ETH}" gateway ""
          /etc/rc.network restart "${ETH}" >/dev/null 2>&1
        fi
      done
    done
    rm -f /etc/sysconfig/network-cmdline.txt
  fi
fi