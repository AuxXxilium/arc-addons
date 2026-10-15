#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# DSM's "arc" notification category, which everything that sends to DSM's own
# notifications goes through: the notification daemon, its --send for Arc
# Control's alerts, and Arc Control itself on a loader built before this.
#
#   arc_notify          %NOTIFICATION%
#   arc_notify_subject  %NOTIFICATION% as the title, %SUBJECT% as the text
#
# Run before the daemon starts, after revert: a loader that still had the
# notify addon, which registered this before it was merged in here, removes
# the category on the first boot without it.
#
#   notification-templates.sh      register the category
#   notification-templates.sh -r   remove it

TEXTS_PATH="/usr/local/share/notification/arc"
CACHE_PATH="/var/cache/texts/arc"

if [ "${1}" = "-r" ]; then
  [ -d "${TEXTS_PATH}" ] && rm -rf "${TEXTS_PATH}"
  [ -d "${CACHE_PATH}" ] && rm -rf "${CACHE_PATH}"
  /usr/syno/bin/notification_utils --remove_category_db_file arc
  /usr/syno/bin/notification_utils --sync_setting_db
  exit 0
fi

for F in $(LC_ALL=C printf '%s\n' /usr/syno/synoman/webman/texts/* | sort -V); do
  [ ! -e "${F}" ] && continue
  NAME=$(basename "${F}")
  rm -rf "${TEXTS_PATH}/${NAME}"
  mkdir -p "${TEXTS_PATH}/${NAME}"
  echo -en '[arc_notify]\nCategory: System\nLevel: NOTIFICATION_INFO\nDesktop: %NOTIFICATION%\n\n\n' >>"${TEXTS_PATH}/${NAME}/mails"
  echo -en '[arc_notify_subject]\nCategory: System\nLevel: NOTIFICATION_INFO\nDesktop: %NOTIFICATION%\nSubject: %NOTIFICATION%\n\n%SUBJECT%\n\nFrom %HOSTNAME%\n\n\n' >>"${TEXTS_PATH}/${NAME}/mails"
done
/bin/rm -rf "${CACHE_PATH}"
/bin/mkdir -p /var/cache/texts
/bin/rsync -ar "${TEXTS_PATH}/" "${CACHE_PATH}"
/usr/syno/bin/notification_utils --remove_category_db_file arc
/usr/syno/bin/notification_utils --gen_category_db_file arc enu
/usr/syno/bin/notification_utils --sync_setting_db
exit 0
