#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# External incoming required ${MLINK} and ${MCHECKSUM}
if [ -z "${MLINK}" ] || [ -z "${MCHECKSUM}" ]; then
  echo "MLINK or MCHECKSUM is null"
  exit 1
fi

install_modules() {
  echo "Installing addon localrss - modules"

  . /etc.defaults/VERSION

  JSON_FILE="/usr/syno/web/localrss.json"
  XML_FILE="/usr/syno/web/localrss.xml"

  cat >"${JSON_FILE}" <<EOF
{
  "version": "2.0",
  "channel": {
    "title": "RSS for DSM Auto Update",
    "link": "https://update.synology.com/autoupdate/v2/getList",
    "pubDate": "Sat May 4 20:30:02 CST 2024",
    "copyright": "Copyright 2024 Synology Inc",
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

  cat >"${XML_FILE}" <<EOF
<?xml version="1.0"?>
<rss version="2.0">
  <channel>
      <title>RSS for DSM Auto Update</title>
      <link>http://update.synology.com/autoupdate/genRSS.php</link>
      <pubDate>Wed May 1 12:02:35 CST 2024</pubDate>
      <copyright>Copyright 2024 Synology Inc</copyright>
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

  if [ -f "${XML_FILE}" ]; then
    sed -i "s|rss_server=.*$|rss_server=\"http://localhost:5000/localrss.xml\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
    sed -i "s|rss_server_ssl=.*$|rss_server_ssl=\"http://localhost:5000/localrss.xml\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
  fi
  if [ -f "${JSON_FILE}" ]; then
    sed -i "s|rss_server_v2=.*$|rss_server_v2=\"http://localhost:5000/localrss.json\"|g" "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"
  fi
  grep "rss_server" "/etc.defaults/synoinfo.conf"
}

case "${1}" in
  modules)
    install_modules
    ;;
  *)
    exit 0
    ;;
esac