#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

echo "==== proc cmdline ===="
cat /proc/cmdline
echo "==== SynoBoot log ===="
cat /var/log/linuxrc.syno.log
echo "==== Installerlog ===="
cat /tmp/installer_sh.log
echo "==== Messages log ===="
cat /var/log/messages