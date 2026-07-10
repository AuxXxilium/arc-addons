#!/bin/sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Logging
_log() {
  echo "netcard: $*"
  /bin/logger -p "error" -t "netcard" "$@"
}

_log "ACTION=${1}, NAME=${2}"

ACTION=$([ "${1}" = "add" ] && echo "restart" || echo "stop")
NAME=${2}

IFCFGPRE="/etc/sysconfig/network-scripts/ifcfg-"

set_kv() {
  # /usr/syno/bin/synosetkeyvalue "$@"
  FILE=${1}
  KEY=${2}
  VALUE=${3}
  if [ -z "${VALUE}" ]; then
    sed -i "/^${KEY}=.*$/d" "${FILE}"
  else
    if grep -qE "^${KEY}=" "${FILE}" 2>/dev/null; then
      sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|g" "${FILE}"
    else
      echo "${KEY}=${VALUE}" >>"${FILE}"
    fi
  fi
}

createifcfg() {
  ETHX=${1}
  if [ -n "$(cat /usr/syno/etc/synoovs/ovs_reg.conf 2>/dev/null)" ]; then
    grep -qw "^${ETHX}" /usr/syno/etc/synoovs/ovs_ignore.conf 2>/dev/null && sed -i "/^${ETHX}$/d" /usr/syno/etc/synoovs/ovs_ignore.conf
    grep -qw "^${ETHX}" /usr/syno/etc/synoovs/ovs_interface.conf 2>/dev/null || echo "${ETHX}" >>/usr/syno/etc/synoovs/ovs_interface.conf
    if [ ! -f "${IFCFGPRE}${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=no\n\nBRIDGE=ovs_${ETHX}" >"${IFCFGPRE}${ETHX}"
    else
      set_kv "${IFCFGPRE}${ETHX}" "BRIDGE" "ovs_${ETHX}"
    fi
    if [ ! -f "${IFCFGPRE}ovs_${ETHX}" ]; then
      echo -e "DEVICE=ovs_${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=no\nPRIMARY=${ETHX}\nTYPE=OVS" >"${IFCFGPRE}ovs_${ETHX}"
    else
      set_kv "${IFCFGPRE}ovs_${ETHX}" "PRIMARY" "${ETHX}"
    fi
    for F in ${IFCFGPRE}ovs_bond*; do
      [ -e "${F}" ] || continue
      if echo "$(get_key_value "${F}" "SLAVE_LIST" 2>/dev/null)" | grep -qw "${ETHX}"; then
        BONDN="$(echo "$(basename "${F}" 2>/dev/null)" | cut -d'-' -f2)"
        set_kv "${IFCFGPRE}ovs_${ETHX}" "SLAVE" "yes"
        set_kv "${IFCFGPRE}${ETHX}" "SLAVE" "yes"
        set_kv "${IFCFGPRE}${ETHX}" "MASTER" "${BONDN}"
      fi
    done
  else
    if [ ! -f "${IFCFGPRE}${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=no" >"${IFCFGPRE}${ETHX}"
    else
      for F in ${IFCFGPRE}bond*; do
        [ -e "${F}" ] || continue
        if echo "$(get_key_value "${F}" "SLAVE_LIST" 2>/dev/null)" | grep -qw "${ETHX}"; then
          BONDN="$(echo "$(basename "${F}" 2>/dev/null)" | cut -d'-' -f2)"
          set_kv "${IFCFGPRE}${ETHX}" "SLAVE" "yes"
          set_kv "${IFCFGPRE}${ETHX}" "MASTER" "${BONDN}"
        fi
      done
    fi
  fi
}

# shellcheck disable=SC2329
deleteifcfg() {
  ETHX=${1}
  if [ -n "$(cat /usr/syno/etc/synoovs/ovs_reg.conf 2>/dev/null)" ]; then
    rm -f "${IFCFGPRE}ovs_${ETHX}"
    rm -f "${IFCFGPRE}${ETHX}"
  else
    rm -f "${IFCFGPRE}${ETHX}"
  fi
}

case "${NAME}" in
eth*)
  ETHX=${NAME}
  [ "${ACTION}" = "restart" ] && createifcfg "${ETHX}" # || deleteifcfg "${ETHX}"
  BRIDGE=$(get_key_value "${IFCFGPRE}${ETHX}" "BRIDGE" 2>/dev/null)
  MASTER=$(get_key_value "${IFCFGPRE}${ETHX}" "MASTER" 2>/dev/null)
  if [ -n "${MASTER}" ]; then
    [ "${ACTION}" = "restart" ] && {
      [ -z "${BRIDGE}" ] && /etc/rc.network "${ACTION}" "${ETHX}"
      set_kv "${IFCFGPRE}${ETHX}" "SLAVE" "no"
      /etc/rc.network "stop" "${ETHX}"
      set_kv "${IFCFGPRE}${ETHX}" "SLAVE" "yes"
    }
    /etc/rc.network "${ACTION}" "${MASTER}"
  elif [ -n "${BRIDGE}" ]; then
    [ "${ACTION}" = "restart" ] && /etc/rc.network "stop" "${ETHX}"
    /etc/rc.network "${ACTION}" "${BRIDGE}"
  else
    /etc/rc.network "${ACTION}" "${ETHX}"
  fi
  ;;
usb*)
  ETHX=$(echo "${NAME}" | sed 's/usb/eth7/')
  if [ "${ACTION}" = "restart" ]; then
    ip link set "${NAME}" down
    ip link set dev "${NAME}" name "${ETHX}"
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
    if [ -x /usr/syno/sbin/synonet ]; then # DSM
      /usr/syno/sbin/synonet --dhcp "${ETHX}" || true
    fi
    if [ -x /sbin/udhcpc ]; then # junior
      if [ -f "/etc/dhcpc/dhcpcd-${ETHX}.pid" ]; then
        kill -9 "$(cat "/etc/dhcpc/dhcpcd-${ETHX}.pid" 2>/dev/null)" || true
        rm -f "/etc/dhcpc/dhcpcd-${ETHX}.pid"
      fi
      /sbin/udhcpc -i "${ETHX}" -p "/etc/dhcpc/dhcpcd-${ETHX}.pid" -b -x "hostname:$(hostname)" || true
    fi
  else
    ip link set "${ETHX}" down
    # deleteifcfg "${ETHX}"
  fi
  ;;
wlan*)
  ETHX=$(echo "${NAME}" | sed 's/wlan/eth8/')
  if [ "${ACTION}" = "restart" ]; then
    ip link set "${NAME}" down
    ip link set dev "${NAME}" name "${ETHX}"
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
  else
    ip link set "${ETHX}" down
    # deleteifcfg "${ETHX}"
  fi
  ;;
*)
  echo "Unknown interface ${NAME}" >&2
  ;;
esac

exit 0
