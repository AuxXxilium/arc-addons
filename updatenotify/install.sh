#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon updatenotify - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  cp -vf /usr/bin/pup /tmpRoot/usr/bin/pup
  cp -vf /usr/bin/updatenotify.sh /tmpRoot/usr/bin/updatenotify.sh

  FILE_PATH="/tmpRoot/usr/syno/etc/synoschedule.d/root"
  mkdir -p "${FILE_PATH}"
  if [ -f "${FILE_PATH}/999.task" ]; then
    NAME="$(cat "${FILE_PATH}/999.task" | grep '^name=' | cut -d'=' -f2)"
    if [ "${NAME}" = "UpdateNotify" ]; then
      echo "Existence tasks"
      exit
    else
      IDX=999
      while [ -f "${FILE_PATH}/${IDX}.task" ]; do IDX=$((${IDX} + 1)); done
      mv -f "${FILE_PATH}/999.task" "${FILE_PATH}/${IDX}.task"
      sed -i "s/id=.*$/id=${IDX}/" "${FILE_PATH}/${IDX}.task"
    fi
  fi

  cat <<EOF >"${FILE_PATH}/999.task"
id=999
last work hour=16
can edit owner=1
can delete from ui=1
edit dialog=SYNO.SDS.TaskScheduler.EditDialog
type=daily
action=#common:run#: /usr/bin/updatenotify.sh
systemd slice=
monthly week=0
can edit from ui=1
week=1111111
app name=#common:command_line#
name=UpdateNotify
can run app same time=1
owner=0
repeat min store config=[1]
repeat hour store config=[8,9,10,11,12,13,14,15,16,17,18,19,20]
simple edit form=1
repeat hour=8
listable=1
app args={"notify_enable":false,"notify_if_error":false,"notify_mail":"","script":"/usr/bin/updatenotify.sh"} 
state=enabled
can run task same time=0
start day=0
cmd=MQ==
run hour=0
edit form=SYNO.SDS.TaskScheduler.Script.FormPanel
app=SYNO.SDS.TaskScheduler.Script
run min=0
start month=0
can edit name=1
start year=0
can run from ui=1
repeat min=0
cmdArgv=
EOF

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon updatenotify - ${1}"

  rm -f "/tmpRoot/usr/bin/updatenotify.sh"

  FILE_PATH="/tmpRoot/usr/syno/etc/synoschedule.d/root"
  if [ -f "${FILE_PATH}/999.task" ]; then
    NAME="$(cat "${FILE_PATH}/999.task" | grep '^name=' | cut -d'=' -f2)"
    if [ "${NAME}" = "UpdateNotify" ]; then
      rm -f "${FILE_PATH}/999.task"
    fi
  fi
fi