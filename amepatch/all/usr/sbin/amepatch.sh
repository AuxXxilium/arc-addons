#!/usr/bin/env ash

scriptver="23.6.1"
script=AmePatch
repo="AuxXxilium/arc-addons"

if [ -d "/var/packages/CodecPack" ]; then

    PATH1="/volume1/@appstore/CodecPack/usr/lib"
    SPATCH="/usr/lib"

    /usr/syno/bin/synopkg stop CodecPack
    sleep 15

    cp -f ${PATH1}/libsynoame-license.so ${PATH1}/libsynoame-license.so.bak
    rm -f ${PATH1}/libsynoame-license.so
    cp -f ${SPATCH}/libsynoame-license.so ${PATH1}/libsynoame-license.so
    chown CodecPack:CodecPack ${PATH1}/libsynoame-license.so
    chmod 0644 ${PATH1}/libsynoame-license.so

    ROOTDISK_PATH=""
    json=${ROOTDISK_PATH}/usr/syno/etc/license/data/ame/offline_license.json
    # apparmor=${ROOTDISK_PATH}/var/packages/CodecPack/target/apparmor
    apparmor=${ROOTDISK_PATH}/volume1/@appstore/CodecPack/apparmor

    mkdir -p "${ROOTDISK_PATH}/usr/syno/etc/license/data/ame"
    echo '[{"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "hevc", "type": "free"}, "licenseContent": 1}, {"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "aac", "type": "free"}, "licenseContent": 1}]' > "${json}"

    /usr/syno/etc/rc.sysv/apparmor.sh remove_packages_profile 0 CodecPack
    # disable apparmor check for AME
    if [ -e "${apparmor}" ]; then
        mv -f "${apparmor}" "${apparmor}.bak"
    fi

    /var/packages/CodecPack/target/usr/bin/synoame-bin-auto-install-needed-codec

    echo -e "AME Patch: Successfull!"

    sleep 5
    /usr/syno/bin/synopkg start CodecPack

fi