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
# the registration survives that.
#
# Watched for a while rather than checked once: on the first boot after an
# installation DSM sets push up itself minutes later, and a registration found
# a minute after boot was gone by then. Any other answer (the service not
# reachable yet) is asked again.

API="/usr/syno/bin/synowebapi"
CONF="/etc/synoinfo.conf"
WATCH=900 # seconds
STEP=30   # seconds
MAXTRIES=3

# To the journal and to /var/log/messages, which DSM keeps far longer.
_log() {
  echo "notification-push: ${1}"
  logger -t notification-push "${1}" 2>/dev/null || true
}

# "ok", the push service's error, or "error" when there is no answer.
_state() {
  "${API}" --exec api=SYNO.Core.Notification.Push.Mobile method=list version=2 2>/dev/null |
    jq -r 'if .data.success then "ok" else (.data.error // "error") end' 2>/dev/null
}

_mobile() {
  "${API}" --exec api=SYNO.Core.Notification.Push.Conf method=set version=1 mobile_enable="${1}" >/dev/null 2>&1
}

TRIES=0
LAST=""
END=$(($(date +%s) + WATCH))
while [ "$(date +%s)" -lt "${END}" ]; do
  STATE="$(_state)"
  case "${STATE}" in
  ok)
    [ "${LAST}" = "ok" ] || _log "registered"
    ;;
  NotRegistered | MissParameter)
    if [ "${TRIES}" -ge "${MAXTRIES}" ]; then
      _log "still ${STATE} after registering again ${TRIES} times, giving up"
      exit 0
    fi
    TRIES=$((TRIES + 1))
    WAS="$(/usr/syno/bin/synogetkeyvalue "${CONF}" pushservice_mobile_enabled)"
    /usr/syno/bin/synosetkeyvalue "${CONF}" pushservice_dstoken "invalid"
    _mobile true
    [ "${WAS}" = "yes" ] || _mobile false
    _log "${STATE}, registering again"
    ;;
  *)
    [ "${LAST}" = "${STATE}" ] || _log "no answer from the push service yet"
    ;;
  esac
  LAST="${STATE}"
  sleep "${STEP}"
done
[ "${LAST}" = "ok" ] || _log "no registration after $((WATCH / 60)) minutes, giving up"
exit 0
