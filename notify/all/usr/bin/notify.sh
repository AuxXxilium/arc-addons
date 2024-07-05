#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "-r" ]; then
  TEXTS_PATH="/usr/local/share/notification/arc"
  CACHE_PATH="/var/cache/texts/arc"
  [ -d "${TEXTS_PATH}" ] && rm -rf "${TEXTS_PATH}"
  [ -d "${CACHE_PATH}" ] && rm -rf "${CACHE_PATH}"
  /usr/syno/bin/notification_utils --remove_category_db_file arc
  /usr/syno/bin/notification_utils --sync_setting_db
else
  TEXTS_PATH="/usr/local/share/notification/arc"
  CACHE_PATH="/var/cache/texts/arc"
  for F in $(ls "/usr/syno/synoman/webman/texts" 2>/dev/null); do
    rm -rf "${TEXTS_PATH}/${F}"
    mkdir -p "${TEXTS_PATH}/${F}"
    echo -en '[arc_notify]\nCategory: System\nLevel: NOTIFICATION_INFO\nDesktop: %NOTIFICATION%\n\n\n' >>"${TEXTS_PATH}/${F}/mails"
    echo -en '[arc_notify_subject]\nCategory: System\nLevel: NOTIFICATION_INFO\nDesktop: %NOTIFICATION%\nSubject: %NOTIFICATION%\n\n%SUBJECT%\n\nFrom %HOSTNAME%\n\n\n' >>"${TEXTS_PATH}/${F}/mails"
  done
  /bin/rm -rf "${CACHE_PATH}"
  /bin/mkdir -p /var/cache/texts
  /bin/rsync -ar "${TEXTS_PATH}/" "${CACHE_PATH}"
  /usr/syno/bin/notification_utils --remove_category_db_file arc
  /usr/syno/bin/notification_utils --gen_category_db_file arc enu
  /usr/syno/bin/notification_utils --sync_setting_db

  # NOTIFICATION="Arc Notify"
  # synodsmnotify -e false -b false "@administrators" "arc_notify" "{\"%NOTIFICATION%\": \"${NOTIFICATION}\"}"
  # NOTIFICATION="Arc Notify"
  # SUBJECT="Welcome to <a href=\\\"https://github.com/AuxXxilium\\" target=blank>AuxXxilium</a>!"
  # synodsmnotify -e false -b false "@administrators" "arc_notify_subject" "{\"%NOTIFICATION%\": \"${NOTIFICATION}\", \"%SUBJECT%\": \"${SUBJECT}\"}"
fi