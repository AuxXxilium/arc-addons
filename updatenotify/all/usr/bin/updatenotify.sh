#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

LOCALTAG="$(cat /usr/arc/VERSION 2>/dev/null | grep LOADERVERSION | cut -d'=' -f2)"
if [ -z "${LOCALTAG}" ]; then
  echo "Unknown bootloader version!"
  exit 0
fi

URL="https://github.com/AuxXxilium/arc"
TAG=""
if echo "$@" | grep -qw "\-p"; then
  TAG="$(curl -skL --connect-timeout 10 "${URL}/tags" | grep /refs/tags/.*\.zip | head -1 | sed -r 's/.*\/refs\/tags\/(.*)\.zip.*$/\1/')"
else
  LATESTURL="$(curl -skL --connect-timeout 10 -w %{url_effective} -o /dev/null "${URL}/releases/latest")"
  TAG="${LATESTURL##*/}"
fi
[ "${TAG:0:1}" = "v" ] && TAG="${TAG:1}"
if [ -z "${TAG}" -o "${TAG}" = "latest" ]; then
  echo "Error checking new version. TAG is ${TAG}"
  exit 0
fi
if [ "${TAG}" = "${LOCALTAG}" ]; then
  echo "Actual version is ${TAG}"
  exit 0
fi

NOTIFICATION="Arc Relase ${TAG}"
SUBJECT="$(curl -skL --connect-timeout 10 "${URL}/releases/tag/${TAG}" | pup 'div[data-test-selector="body-content"]')"
SUBJECT="${SUBJECT//\"/\\\\\\\"}"
synodsmnotify -e false -b false "@administrators" "arc_notify_subject" "{\"%NOTIFICATION%\": \"${NOTIFICATION}\", \"%SUBJECT%\": \"${SUBJECT}\"}"


exit 0