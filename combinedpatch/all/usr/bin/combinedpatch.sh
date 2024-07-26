#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ -d "/var/packages/CodecPack" ]; then
    /usr/syno/etc/rc.sysv/apparmor.sh remove_packages_profile 0 CodecPack

    cp_usr_path="/var/packages/CodecPack/target/usr"
    values=('669066909066906690' 'B801000000' '30')
    hex_values=('1F28' '48F5' '4921' '4953' '4975' '9AC8')
    indices=(0 1 1 1 1 2)
    so="$cp_usr_path/lib/libsynoame-license.so"
    so_backup="$cp_usr_path/lib/libsynoame-license.so.orig"
    lic="/usr/syno/etc/license/data/ame/offline_license.json"
    lic_backup="/usr/syno/etc/license/data/ame/offline_license.json.orig"
    licsig="/usr/syno/etc/license/data/ame/offline_license.sig"
    licsig_backup="/usr/syno/etc/license/data/ame/offline_license.sig.orig"

    if [ ! -f "$so_backup" ]; then
        cp -p "$so" "$so_backup"
    fi
    if [ ! -f "$lic_backup" ]; then
        cp -p "$lic" "$lic_backup"
    fi
    if [ ! -f "$licsig_backup" ]; then
        cp -p "$licsig" "$licsig_backup"
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
        echo "MD5 mismatch"
        exit 1
    fi

    for ((i = 0; i < ${#hex_values[@]}; i++)); do
        offset=$(( 0x${hex_values[i]} + 0x8000 ))
        value=${values[indices[i]]}
        printf '%s' "$value" | xxd -r -p | dd of="$so" bs=1 seek="$offset" conv=notrunc
        if [[ $? -ne 0 ]]; then
            echo "AME Patch: Error while writing to file!"
            exit 1
        fi
    done

    mkdir -p "$(dirname "${lic}")"
    rm -f "${lic}"
    echo "${content}" >"${lic}"

    conf_file="activation.conf"
    conf_path="/usr/syno/etc/codec"
    conf_string='{"success":true,"activated_codec":["hevc_dec","ac3_dec","h264_dec","h264_enc","aac_dec","aac_enc","mpeg4part2_dec","vc1_dec","vc1_enc"],"token":"123456789987654abc"}'
    if [ ! -e "$conf_path/$conf_file" ] ; then
        mkdir -p $conf_path
        echo "$conf_string" > "$conf_path/$conf_file"
        chattr +i "$conf_path/$conf_file"
        echo "Spoofed activation.conf created successfully"
    else
        chattr -i "$conf_path/$conf_file"
        rm "$conf_path/$conf_file"
        echo "$conf_string" > "$conf_path/$conf_file"
        chattr +i "$conf_path/$conf_file"
        echo "Spoofed activation.conf created successfully"
    fi
    
    if "$cp_usr_path/bin/synoame-bin-check-license"; then
        echo -e "AME Patch: Downloading Codec!"
        if "$cp_usr_path/bin/synoame-bin-auto-install-needed-codec"; then
            echo "AME Patch: Successful!"
            exit 0
        fi
    fi
    echo  "AME Patch: Unsuccessful!"
    if [ -f "$so_backup" ]; then
        mv -f "$so_backup" "$so"
    fi
    if [ -f "$lic_backup" ]; then
        mv -f "$lic_backup" "$lic"
    fi
    if [ -f "$licsig_backup" ]; then
        mv -f "$licsig_backup" "$licsig"
    fi
    echo "AME Patch: Backup restored!"
    exit 1
fi
exit 0