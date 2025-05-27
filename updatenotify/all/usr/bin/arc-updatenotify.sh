#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

Create() {
  if grep -q '^name=Arc-UpdateNotify' /usr/syno/etc/synoschedule.d/root/*.task; then
    echo "Existence tasks"
  else
    echo "Create tasks"
    schedule='{"date_type":0,"week_day":"0,1,2,3,4,5,6","repeat_date":1001,"monthly_week":[],"hour":0,"minute":0,"repeat_hour":2,"repeat_min":0,"last_work_hour":0,"repeat_min_store_config":[1,5,10,15,20,30],"repeat_hour_store_config":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]}'
    extra='{"notify_enable":false,"script":"/usr/bin/arc-updatenotify.sh","notify_mail":"","notify_if_error":false}'
    synowebapi -s --exec api=SYNO.Core.TaskScheduler.Root method=create version=4 name='"Arc-UpdateNotify"' owner='"root"' enable=true schedule="${schedule}" extra="${extra}" type='"script"'
  fi
  exit 0
}

Delete() {
  for F in /usr/syno/etc/synoschedule.d/root/*.task; do
    [ ! -e "${F}" ] && continue
    if grep -q '^name=Arc-UpdateNotify' "${F}"; then
      id=$(grep '^id=' "${F}" | cut -d'=' -f2)
      [ -n "${id}" ] && synoschedtask --del id=${id}
    fi
  done
  exit 0
}

Check() {
  LOCALTAG=$(grep LOADERVERSION /usr/arc/VERSION 2>/dev/null | cut -d'=' -f2 | sed 's/\"//g')
  if [ -z "${LOCALTAG}" ]; then
    echo "Unknown bootloader version!"
    exit 0
  fi

  URL="https://github.com/AuxXxilium/arc"
  TAG=""
  if echo "$@" | grep -wq "\-p"; then
    TAG=$(curl -skL --connect-timeout 10 "${URL}/tags" | grep "/refs/tags/.*\.zip" | head -1 | sed -E 's/.*\/refs\/tags\/(.*)\.zip.*$/\1/')
  else
    # shellcheck disable=SC1083
    TAG="$(curl -skL --connect-timeout 10 -w %{url_effective} -o /dev/null "${URL}/releases/latest" | awk -F'/' '{print $NF}')"
  fi
  [ "${TAG:0:1}" = "v" ] && TAG="${TAG:1}"
  if [ -z "${TAG}" ] || [ "${TAG}" = "latest" ]; then
    echo "Error checking new version - Your version is ${LOCALTAG}"
    exit 0
  fi
  if [ "${TAG}" = "${LOCALTAG}" ]; then
    echo "Actual version is ${TAG} - Your version is ${LOCALTAG}"
    exit 0
  fi

  NOTIFICATION="Arc Release ${TAG}"
  SUBJECT=$(curl -skL --connect-timeout 10 "${URL}/releases/tag/${TAG}" | pup 'div[data-test-selector="body-content"]')
  SUBJECT="${SUBJECT//\"/\\\\\\\"}"
  synodsmnotify -e false -b false "@administrators" "arc_notify_subject" "{\"%NOTIFICATION%\": \"${NOTIFICATION}\", \"%SUBJECT%\": \"${SUBJECT}\"}"

  exit 0
}

ACTION="${1}"
[ -z "${ACTION}" ] && ACTION="check"

case "${ACTION,,}" in
  "create")
    Create
    ;;
  "delete")
    Delete
    ;;
  "check")
    shift
    Check "$@"
    ;;
esac
exit 0