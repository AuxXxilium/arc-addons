#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

sendWebhook() {
  local URL="${1}"
  local MSGT="${2:-"Notification from Arc Loader"}"
  local MSGC="${3:-"$(date +'%Y-%m-%d %H:%M:%S')"}"

  [ -z "${URL}" ] && return 1

  curl -skL -X POST -H "Content-Type: application/json" -d "{\"title\":\"${MSGT}\", \"text\":\"${MSGC}\"}" "${URL}" >/dev/null 2>&1
  return $?
}

sendDiscord() {
  local USERID="${1}"
  local MSGT="${2:-"Notification from Arc Loader"}"
  local MSGC="${3:-"$(date +'%Y-%m-%d %H:%M:%S')"}"

  [ -z "${USERID}" ] && return 1

  local MESSAGE="${MSGT}: ${MSGC}"
  local ENCODED_MSG=$(echo "${MESSAGE}" | jq -sRr @uri)
  curl -skL "https://arc.auxxxilium.tech/notify.php?id=${USERID}&message=${ENCODED_MSG}" >/dev/null 2>&1
  return $?
}

getIP() {
  local iface="${1}"
  ip -4 -o addr show "${iface}" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 | grep -v "^169\.254\." | head -1
}

local WEBHOOKURL DISCORDUSERID IPCON ARC_VERSION

WEBHOOKURL="${1}"
DISCORDUSERID="${2}"

IPCON=""
for iface in $(ls /sys/class/net/ | grep '^eth'); do
  ip="$(getIP "${iface}")"
  if [ -n "${ip}" ]; then
    IPCON="${ip}"
    break
  fi
done

ARC_VERSION="Arc $(cat /usr/arc/VERSION 2>/dev/null | grep LOADERVERSION | cut -d'=' -f2 | sed 's/"//g')" || ARC_VERSION="Arc Loader"

if [ -n "${WEBHOOKURL}" ]; then
  sendWebhook "${WEBHOOKURL}" "${ARC_VERSION}" "DSM is running @ ${IPCON}"
fi
if [ -n "${DISCORDUSERID}" ]; then
  sendDiscord "${DISCORDUSERID}" "${ARC_VERSION}" "DSM is running @ ${IPCON}"
fi