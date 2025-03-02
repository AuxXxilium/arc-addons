#!/usr/bin/env ash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
if [ "${1}" = "patches" ]; then
  echo "Installing addon blockupdates - ${1}"

  cp -pf /usr/syno/sbin/bootup-smallupdate.sh /usr/syno/sbin/bootup-smallupdate.sh.bak
  echo -en '#!/bin/sh\nexit 0\n' >/usr/syno/sbin/bootup-smallupdate.sh

elif [ "${1}" = "late" ]; then
  echo "Installing addon blockupdates - ${1}"
  mkdir -p "/tmpRoot/usr/rr/addons/"
  cp -pf "${0}" "/tmpRoot/usr/rr/addons/"

  sed -i 's|rss_server=.*$|rss_server=http://127.0.0.1/autoupdate/genRSS.php|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf
  sed -i 's|rss_server_ssl=.*$|rss_server_ssl=https://127.0.0.1/autoupdate/genRSS.php|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf
  sed -i 's|rss_server_v2=.*$|rss_server_v2=https://127.0.0.1/autoupdate/v2/getList|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf

  rm -rf /tmpRoot/var/update/check_result/*
  mkdir -p /tmpRoot/var/update/check_result
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"none","restartType":"none","updateType":"none","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/security_version
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"none","restartType":"none","updateType":"none","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/promotion
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"now","restartType":"none","updateType":"system","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/update

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon blockupdates - ${1}"

  sed -i 's|rss_server=.*$|rss_server="http://update7.synology.com/autoupdate/genRSS.php"|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf
  sed -i 's|rss_server_ssl=.*$|rss_server_ssl="https://update7.synology.com/autoupdate/genRSS.php"|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf
  sed -i 's|rss_server_v2=.*$|rss_server_v2="https://update7.synology.com/autoupdate/v2/getList"|' /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf

  rm -rf /tmpRoot/var/update/check_result/*

fi
