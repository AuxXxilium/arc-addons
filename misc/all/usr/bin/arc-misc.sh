#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

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

  [ -f "${file}" ] || touch "${file}"
  # Replaces the key in the section, or adds it at the section's end, or
  # adds the section at the end of the file.
  awk -v section="${section}" -v key="${key}" -v value="${value}" '
    function put() { if (in_section && !done && key != "") { print "\t" key "=" value; done=1 } }
    $0 ~ "^[[:space:]]*\\[" {
      put()
      in_section = ($0 ~ "^[[:space:]]*\\["section"\\][[:space:]]*$")
      if (in_section) found=1
      print
      next
    }
    in_section && key != "" && $0 ~ "^[[:space:]]*"key"=" { put(); next }
    { print }
    END {
      put()
      if (!found) {
        print "[" section "]"
        if (key != "") print "\t" key "=" value
      }
    }
  ' "${file}" >"${file}.tmp" && cat "${file}.tmp" >"${file}"
  rm -f "${file}.tmp"
}

GCKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/usr/bin/get_key_value")
SCKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/usr/bin/set_key_value")
GSKV=$([ -x "/usr/syno/bin/get_section_key_value" ] && echo "/usr/syno/bin/get_section_key_value" || echo "get_section_kv")
SSKV=$([ -x "/usr/syno/bin/set_section_key_value" ] && echo "/usr/syno/bin/set_section_key_value" || echo "set_section_kv")

###############################################################################

# packages
[ -f /usr/syno/etc/packages/feeds ] && rm -f /usr/syno/etc/packages/feeds
mkdir -p /usr/syno/etc/packages
echo '[{"feed":"https://apps.xpenology.tech","name":"xpenology"},{"feed":"https://packages.synocommunity.com","name":"synocommunity"},{"feed":"https://spk7.imnks.com","name":"imnks"}]' >/usr/syno/etc/packages/feeds

# network
# Static addresses from the loader's network.<mac>=address/netmask/gateway/dns
# entries. Each one is applied to the interface with that original MAC, and
# recorded in NCF; a NIC recorded last time with no entry now goes back to DHCP.
NCF="/etc/sysconfig/network-cmdline.txt"
GWDB="/etc/iproute2/config/gateway_database"

# A network.<mac>=... entry's MAC, lower case without colons.
net_mac() {
  echo "${1%%=*}" | cut -d. -f2 | sed 's/://g; s/.*/\L&/'
}

# The physical interface whose original MAC is ${1}. Bonds and bridges carry
# their member's MAC too, so only interfaces with a device behind them count.
net_eth() {
  /usr/syno/sbin/synonet --show 2>/dev/null | grep "interface: " | awk '{print $NF}' | while read -r ETH; do
    [ -e "/sys/class/net/${ETH}/device" ] || continue
    MACX="$(/usr/syno/sbin/synonet --get_mac_addr "${ETH}" original 2>/dev/null | awk -F'Mac is: ' '{print $2}' | sed 's/://g; s/.*/\L&/')"
    if [ "${1}" = "${MACX}" ]; then
      echo "${ETH}"
      break
    fi
  done
}

# The interface whose ifcfg holds ${1}'s address: itself, the bond it is a
# slave of, or the Open vSwitch bridge either one is attached to.
net_target() {
  local T="${1}" M B
  M="$(${GCKV} "/etc/sysconfig/network-scripts/ifcfg-${T}" "MASTER" 2>/dev/null)"
  [ -n "${M}" ] && T="${M}"
  B="$(${GCKV} "/etc/sysconfig/network-scripts/ifcfg-${T}" "BRIDGE" 2>/dev/null)"
  [ -n "${B}" ] && T="${B}"
  echo "${T}"
}

# Applies address/netmask/gateway/dns ${2} to interface ${1}. The interface is
# restarted only if its ifcfg changed: rc.network has already brought it up
# from that file at this boot.
net_static() {
  local T CF IP MASK GW DNS
  T="$(net_target "${1}")"
  CF="/etc/sysconfig/network-scripts/ifcfg-${T}"
  IFS='/' read -r IP MASK GW DNS <<<"${2}"
  [ -z "${IP}" ] && return
  echo "Setting IP for ${1} (${T}) to ${2}"
  if [ "$(${GCKV} "${CF}" "BOOTPROTO")" = "static" ] &&
    [ "$(${GCKV} "${CF}" "IPADDR")" = "${IP}" ] &&
    [ "$(${GCKV} "${CF}" "NETMASK")" = "${MASK}" ] &&
    [ "$(${GCKV} "${CF}" "GATEWAY")" = "${GW}" ] &&
    [ "$(${GSKV} "${GWDB}" "${T}" dns 2>/dev/null)" = "${DNS}" ]; then
    return
  fi
  ${SCKV} "${CF}" "BOOTPROTO" "static"
  ${SCKV} "${CF}" "ONBOOT" "yes"
  ${SCKV} "${CF}" "IPADDR" "${IP}"
  ${SCKV} "${CF}" "NETMASK" "${MASK}"
  if [ -n "${GW}" ]; then
    ${SCKV} "${CF}" "GATEWAY" "${GW}"
  else
    sed -i '/^GATEWAY=/d' "${CF}"
  fi
  ${SSKV} "${GWDB}" "${T}" dns "${DNS}"
  ${SSKV} "${GWDB}" "${T}" gateway "${GW}"
  /etc/rc.network restart "${T}" >/dev/null 2>&1
}

# Puts interface ${1} back on DHCP.
net_dhcp() {
  local T CF
  T="$(net_target "${1}")"
  CF="/etc/sysconfig/network-scripts/ifcfg-${T}"
  echo "Setting IP for ${1} (${T}) to dhcp"
  sed -i "s|^BOOTPROTO=.*|BOOTPROTO=dhcp|; s|^ONBOOT=.*|ONBOOT=yes|; /^IPADDR=/d; /^NETMASK=/d; /^GATEWAY=/d; /^DNS1=/d; /^DNS2=/d" "${CF}"
  ${SSKV} "${GWDB}" "${T}" dns ""
  ${SSKV} "${GWDB}" "${T}" gateway ""
  /etc/rc.network restart "${T}" >/dev/null 2>&1
}

NETS="$(tr ' ' '\n' </proc/cmdline | grep -E '^network\.[0-9a-fA-F:]{12,17}=')"
MACS="$(for I in ${NETS}; do net_mac "${I}"; done)"
if [ -f "${NCF}" ]; then
  for I in $(cat "${NCF}"); do
    MACR="$(net_mac "${I}")"
    echo "${MACS}" | grep -qx "${MACR}" && continue
    ETH="$(net_eth "${MACR}")"
    [ -n "${ETH}" ] && net_dhcp "${ETH}"
  done
fi
for I in ${NETS}; do
  ETH="$(net_eth "$(net_mac "${I}")")"
  [ -n "${ETH}" ] && net_static "${ETH}" "${I#*=}"
done
if [ -n "${NETS}" ]; then
  echo "${NETS}" >"${NCF}"
else
  rm -f "${NCF}"
fi

# fix size units: replace SI prefixes with correct binary (IEC) prefixes in DSM UI strings
for F in /usr/syno/synoman/webman/texts/*/strings; do
  [ -f "${F}" ] || continue
  sed -i 's/"KB"/"KiB"/g; s/"MB"/"MiB"/g; s/"GB"/"GiB"/g; s/"TB"/"TiB"/g' "${F}"
  # German and Czech use lowercase kB for kilobyte
  case "${F}" in */ger/strings|*/csy/strings) sed -i 's/"kB"/"KiB"/g' "${F}" ;; esac
  # French uses Ko/Mo/Go/To
  case "${F}" in */fre/strings) sed -i 's/"Ko"/"Kio"/g; s/"Mo"/"Mio"/g; s/"Go"/"Gio"/g; s/"To"/"Tio"/g' "${F}" ;; esac
  # Russian uses Cyrillic
  case "${F}" in */rus/strings) sed -i 's/"КБ"/"КиБ"/g; s/"МБ"/"МиБ"/g; s/"ГБ"/"ГиБ"/g; s/"ТБ"/"ТиБ"/g' "${F}" ;; esac
done
