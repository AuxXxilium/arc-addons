#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

echo -en "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

if ps -aux | grep -v grep | grep -q sshx; then
  kill "$(ps -aux | grep -v grep | grep sshx | awk '{print $2}')"
  echo "sshx is killed"
  exit 0
else
  sshx -q --name "Arc Assistance" 2>&1 &
  sleep 1
  echo "sshx is started"
fi
