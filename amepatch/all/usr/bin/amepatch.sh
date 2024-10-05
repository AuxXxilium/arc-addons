#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ -d "/var/packages/CodecPack" ]; then
    /usr/syno/etc/rc.sysv/apparmor.sh remove_packages_profile 0 CodecPack

    [ -f "/var/packages/CodecPack/target/apparmor" ] && mv -f "/var/packages/CodecPack/target/apparmor" "/var/packages/CodecPack/target/apparmor.bak"

    ame_path="/var/packages/CodecPack/target/usr"
    values=('669066909066906690' 'B801000000' '30')
    indices=(0 1 1 1 1 2)
    so="$ame_path/lib/libsynoame-license.so"
    so_backup="$ame_path/lib/libsynoame-license.so.orig"
    lic="/usr/syno/etc/license/data/ame/offline_license.json"
    lic_backup="/usr/syno/etc/license/data/ame/offline_license.json.orig"
    lic_patched="/usr/arc/ame_license.patched"

    if [ -f "$lic_patched" ]; then
        if "$ame_path/bin/synoame-bin-auto-install-needed-codec"; then
            echo -e "AME Patch: Already patched! -> Codec downloaded!"
            exit 0
        else
            echo -e "AME Patch: Already patched! -> Codec download failed!"
            exit 1
        fi
    fi

    if [ ! -f "$so_backup" ]; then
        cp -p "$so" "$so_backup"
    fi
    if [ ! -f "$lic_backup" ]; then
        cp -p "$lic" "$lic_backup"
    fi

    hash_to_check="$(md5sum -b "$so" | awk '{print $1}')"

    if [ "$hash_to_check" = "fcc1084f4eadcf5855e6e8494fb79e23" ]; then
        hex_values=('1F28' '48F5' '4921' '4953' '4975' '9AC8')
        content='[{"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "hevc", "type": "free"}, "licenseContent": 1}, {"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "aac", "type": "free"}, "licenseContent": 1}]'
    elif [ "$hash_to_check" = "923fd0d58e79b7dc0f6c377547545930" ]; then
        hex_values=('1F28' '48F5' '4921' '4953' '4975' '9AC8')
        content='[{"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "hevc", "type": "free"}, "licenseContent": 1}, {"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "aac", "type": "free"}, "licenseContent": 1}]'
    elif [ "$hash_to_check" = "09e3adeafe85b353c9427d93ef0185e9" ]; then
        hex_values=('3718' '60A5' '60D1' '6111' '6137' 'B5F0')
        content='[{"attribute": {"codec": "hevc", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}, {"attribute": {"codec": "aac", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}]'
    else
        echo -e "AME Patch: Unsupported version!"
        exit 1
    fi

    for ((i = 0; i < ${#hex_values[@]}; i++)); do
        offset=$(( 0x${hex_values[i]} + 0x8000 ))
        value=${values[indices[i]]}
        printf '%s' "$value" | xxd -r -p | dd of="$so" bs=1 seek="$offset" conv=notrunc
        if [[ $? -ne 0 ]]; then
            echo -e "AME Patch: Error while writing to file!"
            exit 1
        fi
    done

    mkdir -p "$(dirname "${lic}")"
    rm -f "${lic}"
    echo "${content}" >"${lic}"

    if "$ame_path/bin/synoame-bin-check-license"; then
        echo -e "AME Patch: Downloading Codec!"
        echo "true" >"${lic_patched}"
        if "$ame_path/bin/synoame-bin-auto-install-needed-codec"; then
            echo -e "AME Patch: Successful!"
            exit 0
        else
            echo -e "AME Patch: Failed!"
            exit 1
        fi
    else
        if [ -f "$so_backup" ]; then
            mv -f "$so_backup" "$so"
        fi
        if [ -f "$lic_backup" ]; then
            mv -f "$lic_backup" "$lic"
        fi
        rm -f "$lic_patched"
        echo -e "AME Patch: Backup restored!"
        exit 1
    fi
else
    echo -e "AME Patch: CodecPack not found!"
    exit 1
fi