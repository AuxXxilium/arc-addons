#!/usr/bin/env ash

scriptver="23.7.1"
script=AmePatch
repo="AuxXxilium/arc-addons"

if [[ -d /var/packages/CodecPack ]]; then
    /usr/syno/bin/synopkg stop CodecPack
    sleep 10

    . /etc.defaults/VERSION
    values=('669066909066906690' 'B801000000' '30')
    indices=(0 1 1 1 1 2)
    cp_usr_path='/var/packages/CodecPack/target/usr'
    so="$cp_usr_path/lib/libsynoame-license.so"
    lic="/usr/syno/etc/license/data/ame/offline_license.json"
    licsig="/usr/syno/etc/license/data/ame/offline_license.sig"

    if [[ $majorversion = 7 && $minorversion > 2 ]]; then
        expected_checksum='fcc1084f4eadcf5855e6e8494fb79e23'
        hex_values=('1F28' '48F5' '4921' '4953' '4975' '9AC8')
        content= '[{"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "hevc", "type": "free"}, "licenseContent": 1}, {"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "aac", "type": "free"}, "licenseContent": 1}]'
    elif [[ $majorversion = 7 && $minorversion = 2 ]]; then
        expected_checksum='09e3adeafe85b353c9427d93ef0185e9'
        hex_values=('3718' '60A5' '60D1' '6111' '6137' 'B5F0')
        content='[{"attribute": {"codec": "hevc", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}, {"attribute": {"codec": "aac", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}]'
    fi

    if [[ "$(md5sum -b "$so" | awk '{print $1}')" != "$expected_checksum" ]]; then
        echo -e "AME Patch: MD5 mismatch"
        exit 1
    fi

    for ((i = 0; i < ${#hex_values[@]}; i++)); do
        offset=$(( 0x${hex_values[i]} + 0x8000 ))
        value=${values[indices[i]]}
        printf '%s' "$value" | xxd -r -p | dd of="$so" bs=1 seek="$offset" conv=notrunc
        if [[ $? != 0 ]]; then
            echo -e "AME Patch: Error while writing to file!"
            exit 1
        fi
    done

    mkdir -p "$(dirname "$lic")"
    echo "$content" > "$lic"

	if "$cp_usr_path/bin/synoame-bin-check-license"; then
        "$cp_usr_path/bin/synoame-bin-auto-install-needed-codec"
        /var/packages/CodecPack/target/usr/bin/synoame-bin-auto-install-needed-codec
        echo -e "AME Patch: Successful!"
    else
        echo -e "AME Patch: Unsuccessful!"
        exit 1
   	fi

    sleep 5
    /usr/syno/bin/synopkg start CodecPack
fi