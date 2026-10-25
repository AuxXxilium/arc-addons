#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Keeps DSM registered with Synology's push service (sns.synology.com), so
# Control Panel > Notification > Push Service loads instead of saying it could
# not load the system settings.
#
# DSM registers under its serial and first vendor MAC, and the service keeps
# one registration per identity: another box with the same serial and MAC - as
# every Arc Patch box of a model has - takes it over, and the token here goes
# stale ("NotRegistered"). A missing token ("MissParameter"), as a first boot
# before the setup wizard can leave, DSM never replaces on its own.
#
# DSM fetches a new token only when it finds the one it has invalid, while
# switching mobile notifications on. So the token is replaced by a placeholder,
# mobile notifications are switched on, and the user's setting is put back -
# the registration survives that. A registered DSM is left alone, and any other
# answer (the service not reachable yet) is asked again.

API="/usr/syno/bin/synowebapi"
CONF="/etc/synoinfo.conf"

# "ok", the push service's error, or "error" when there is no answer.
_state() {
  "${API}" --exec api=SYNO.Core.Notification.Push.Mobile method=list version=2 2>/dev/null |
    jq -r 'if .data.success then "ok" else (.data.error // "error") end' 2>/dev/null
}

_mobile() {
  "${API}" --exec api=SYNO.Core.Notification.Push.Conf method=set version=1 mobile_enable="${1}" >/dev/null 2>&1
}

TRIES=0
for _ in $(seq 1 18); do
  STATE="$(_state)"
  case "${STATE}" in
  ok)
    echo "notification-push: registered"
    exit 0
    ;;
  NotRegistered | MissParameter)
    if [ "${TRIES}" -ge 2 ]; then
      echo "notification-push: still ${STATE} after registering again, giving up"
      exit 0
    fi
    TRIES=$((TRIES + 1))
    WAS="$(/usr/syno/bin/synogetkeyvalue "${CONF}" pushservice_mobile_enabled)"
    /usr/syno/bin/synosetkeyvalue "${CONF}" pushservice_dstoken "invalid"
    _mobile true
    [ "${WAS}" = "yes" ] || _mobile false
    echo "notification-push: ${STATE}, registering again"
    ;;
  esac
  sleep 10
done
echo "notification-push: no answer from the push service, giving up"
exit 0
