#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon smartctl - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  FILE="/tmpRoot/usr/bin/smartctl"
  # The wrapper runs smartctl.bak, so it must never be backed up as it. Still
  # the wrapper, FILE was not shipped again and the backup stands as it is.
  grep -qF "smartctl.bak" "${FILE}" 2>/dev/null || /usr/bin/arc-backup.sh take "${FILE}"
  cp -vpf /usr/bin/smartctl.sh "${FILE}"
  /usr/bin/arc-backup.sh seal "${FILE}"
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon smartctl - ${1}"

  FILE="/tmpRoot/usr/bin/smartctl"
  /usr/bin/arc-backup.sh restore "${FILE}"
fi