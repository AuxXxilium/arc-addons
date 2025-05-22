#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# shellcheck disable=SC3037

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

echo "Starting ttyd ..."

{
  echo "Arc Recovery Mode"
  echo
  echo "Using terminal commands to modify system configs, execute external binary"
  echo "files, add files, or install unauthorized third-party apps may lead to system"
  echo "damages or unexpected behavior, or cause data loss. Make sure you are aware of"
  echo "the consequences of each command and proceed at your own risk."
  echo
  echo "Warning: Data should only be stored in shared folders. Data stored elsewhere"
  echo "may be deleted when the system is updated/restarted."
  echo
  echo "'System partition /dev/md0 mounted to': /tmpRoot"
  echo "To 'Force re-install DSM': http://<ip>:5000/web_install.html"
  echo "To 'Reboot to Config Mode': http://<ip>:5000/webman/reboot_to_loader.cgi"
  echo "To 'Show Boot Log': http://<ip>:5000/webman/get_logs.cgi""
} >/etc/motd

/usr/bin/killall ttyd 2>/dev/null || true
/usr/sbin/ttyd -W -t titleFixed="Arc Recovery" login -f root >/dev/null 2>&1 &

echo "Starting dufs ..."
/usr/bin/killall dufs 2>/dev/null || true
/usr/sbin/dufs -A -p 7304 / >/dev/null 2>&1 &

cp -pf /usr/syno/web/web_index.html /usr/syno/web/web_install.html
cp -pf /addons/web_index.html /usr/syno/web/web_index.html
mkdir -p /tmpRoot
mount /dev/md0 /tmpRoot
echo "Recovery mode is ready"