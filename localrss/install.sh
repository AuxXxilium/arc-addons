#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# External incoming required ${MLINK} and ${MCHECKSUM}
if [ -z "${MLINK}" -o -z "${MCHECKSUM}" ]; then
  echo "MLINK or MCHECKSUM is null"
  return
fi

if [ "${1}" = "modules" ]; then
  echo "Installing addon localrss - ${1}"

  # MajorVersion=`/bin/get_key_value /etc.defaults/VERSION majorversion`
  # MinorVersion=`/bin/get_key_value /etc.defaults/VERSION minorversion`
  . /etc.defaults/VERSION

  cat >/usr/syno/web/localrss.json <<EOF
{
  "version": "2.0",
  "channel": {
    "title": "RSS for DSM Auto Update",
    "link": "https://update.synology.com/autoupdate/v2/getList",
    "pubDate": "Sat Aug 6 0:18:39 CST 2022",
    "copyright": "Copyright 2022 Synology Inc",
    "item": [
      {
        "title": "DSM ${productversion}-${buildnumber}",
        "MajorVer": ${major},
        "MinorVer": ${minor},
        "NanoVer": ${micro},
        "BuildPhase": "${buildphase}",
        "BuildNum": ${buildnumber},
        "BuildDate": "${builddate}",
        "ReqMajorVer": ${major},
        "ReqMinorVer": 0,
        "ReqBuildPhase": 0,
        "ReqBuildNum": 0,
        "ReqBuildDate": "${builddate}",
        "isSecurityVersion": false,
        "model": [
            {
                "mUnique": "${unique}",
                "mLink": "${MLINK}",
                "mCheckSum": "${MCHECKSUM}"
            }
        ]
      }
    ]
  }
}
EOF

  cat >/usr/syno/web/localrss.xml <<EOF
<?xml version="1.0"?>
<rss version="2.0">
  <channel>
      <title>RSS for DSM Auto Update</title>
      <link>http://update.synology.com/autoupdate/genRSS.php</link>
      <pubDate>Tue May 9 11:52:15 CST 2023</pubDate>
      <copyright>Copyright 2023 Synology Inc</copyright>
    <item>
      <title>DSM ${productversion}-${buildnumber}</title>
      <MajorVer>${major}</MajorVer>
      <MinorVer>${minor}</MinorVer>
      <BuildPhase>${buildphase}</BuildPhase>
      <BuildNum>${buildnumber}</BuildNum>
      <BuildDate>${builddate}</BuildDate>
      <ReqMajorVer>${major}</ReqMajorVer>
      <ReqMinorVer>0</ReqMinorVer>
      <ReqBuildPhase>0</ReqBuildPhase>
      <ReqBuildNum>0</ReqBuildNum>
      <ReqBuildDate>${builddate}</ReqBuildDate>
      <model>
        <mUnique>${unique}</mUnique>
        <mLink>${MLINK}</mLink>
        <mCheckSum>${MCHECKSUM}</mCheckSum>
      </model>
    </item>
  </channel>
</rss>
EOF

  if [ -f /usr/syno/web/localrss.xml ]; then
    cat /usr/syno/web/localrss.xml
    sed -i "s|rss_server=.*$|rss_server=\"http://localhost:5000/localrss.xml\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
    sed -i "s|rss_server_ssl=.*$|rss_server_ssl=\"http://localhost:5000/localrss.xml\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
  fi
  if [ -f /usr/syno/web/localrss.json ]; then
    cat /usr/syno/web/localrss.json
    sed -i "s|rss_server_v2=.*$|rss_server_v2=\"http://localhost:5000/localrss.json\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
  fi
fi