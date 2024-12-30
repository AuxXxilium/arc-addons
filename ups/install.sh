#!/usr/bin/env ash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon ups - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  
  FILE="/tmpRoot/usr/syno/bin/synoups"
  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"

  cp -pf "${FILE}.bak" "${FILE}"
  if [ -z "${2}" ] || [ "${2}" = "-f" ]; then
    sed -i "s|/usr/syno/sbin/synopoweroff.*$|/usr/syno/sbin/synopoweroff|g" "${FILE}"
  fi
  if [ "${2}" = "-e" ] || [ "${2}" = "-f" ]; then
    EVENT_POWEROFF="/usr/syno/sbin/esynoscheduler --fireEvent event=shutdown"
    if ! grep -q "${EVENT_POWEROFF}" "${FILE}"; then
      sed -i "/\/usr\/syno\/sbin\/synopoweroff/i\ \ \ \ ${EVENT_POWEROFF}" "${FILE}"
    fi

    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -wq "task"; then
      echo "copy esynoscheduler.db"
      mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
      cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
    fi
    echo "insert start/stop ScsiTarget task to esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'StartScsiTarget';
INSERT INTO task VALUES('StartScsiTarget', '', 'bootup', '', 1, 0, 0, 0, '', 0, "synopkg start ScsiTarget", 'script', '{}', '', '', '{}', '{}');
DELETE FROM task WHERE task_name LIKE 'StopScsiTarget';
INSERT INTO task VALUES('StopScsiTarget', '', 'shutdown', '', 1, 0, 0, 0, '', 0, "synopkg stop ScsiTarget", 'script', '{}', '', '', '{}', '{}');
EOF
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ups - ${1}"

  FILE="/tmpRoot/usr/syno/bin/synoups"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete start/stop ScsiTarget task from esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'StartScsiTarget';
DELETE FROM task WHERE task_name LIKE 'StopScsiTarget';
EOF
  fi
fi
