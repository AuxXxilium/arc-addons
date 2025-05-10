#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_patches() {
  echo "Installing addon blockupdates - patches"
  cp -pf /usr/syno/sbin/bootup-smallupdate.sh /usr/syno/sbin/bootup-smallupdate.sh.bak
  printf '#!/bin/sh\nexit 0\n' >/usr/syno/sbin/bootup-smallupdate.sh
}

install_late() {
  echo "Installing addon blockupdates - late"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do
    /bin/set_key_value "${F}" "rss_server" "http://127.0.0.1/autoupdate/genRSS.php"
    /bin/set_key_value "${F}" "rss_server_ssl" "https://127.0.0.1/autoupdate/genRSS.php"
    /bin/set_key_value "${F}" "rss_server_v2" "https://127.0.0.1/autoupdate/v2/getList"
  done

  rm -rf /tmpRoot/var/update/check_result/*
  mkdir -p /tmpRoot/var/update/check_result
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"none","restartType":"none","updateType":"none","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/security_version
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"none","restartType":"none","updateType":"none","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/promotion
  echo '{"blAvailable":false,"checkRSSResult":"success","rebootType":"now","restartType":"none","updateType":"system","version":{"iBuildNumber":0,"iMajor":0,"iMajorOrigin":0,"iMicro":0,"iMinor":0,"iMinorOrigin":0,"iNano":0,"jDownloadMeta":null,"strOsName":"","strUnique":"","tags":[]}}' >/tmpRoot/var/update/check_result/update
}

uninstall() {
  echo "Installing addon blockupdates - uninstall"
  for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do
    /bin/set_key_value "${F}" "rss_server" "http://update7.synology.com/autoupdate/genRSS.php"
    /bin/set_key_value "${F}" "rss_server_ssl" "https://update7.synology.com/autoupdate/genRSS.php"
    /bin/set_key_value "${F}" "rss_server_v2" "https://update7.synology.com/autoupdate/v2/getList"
  done

  rm -rf /tmpRoot/var/update/check_result/*
}

case "${1}" in
  patches) install_patches ;;
  late) install_late ;;
  uninstall) uninstall ;;
esac
exit 0