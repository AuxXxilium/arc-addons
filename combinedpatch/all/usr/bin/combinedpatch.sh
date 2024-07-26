#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -eo pipefail;
shopt -s nullglob;

declare -A binhash_version_list=(
    ["cde88ed8fdb2bfeda8de52ef3adede87a72326ef"]="6.0-7321-0_6.0.3-8754-8"
    ["ec0c3f5bbb857fa84f5d1153545d30d7b408520b"]="6.1-15047-0_6.1.1-15101-4"
    ["1473d6ad6ff6e5b8419c6b0bc41006b72fd777dd"]="6.1.2-15132-0_6.1.3-15152-8"
    ["26e42e43b393811c176dac651efc5d61e4569305"]="6.1.4-15217-0_6.2-23739-2"
    ["1d01ee38211f21c67a4311f90315568b3fa530e6"]="6.2.1-23824-0_6.2.3-25426-3"
    ["c2f07f4cebf0bfb63e3ca38f811fd5b6112a797e"]="7.0.1-42216-0_7.0.1-42218-3"
    ["796ac7fab2dcad7978a0e8ae48abc9150aba916c"]="7.1-42661-0_7.1-42661-0"
    ["22445f5b0d8b6714954b50930c47b8805cf32b98"]="7.1-42661-0_7.1-42661-0"
    ["18461b62813166652fd64a96e06237fde81925f7"]="7.1.1-42962-0_7.1.1-42962-6"
    ["d316d5b2b080346b4bc197ad5ad7994ac043a15d"]="7.2-64570-0_7.2-64570-3"
    ["a205aa337d808213cf6d4d839b035cde0237b424"]="7.2.1-69057-0_7.2.1-69057-5"
)

declare -A patchhash_binhash_list=(
    ["e5c1a65b3967968560476fcda5071fd37db40223"]="cde88ed8fdb2bfeda8de52ef3adede87a72326ef"
    ["d58f5b33ff2b6f2141036837ddf15dd5188384c6"]="ec0c3f5bbb857fa84f5d1153545d30d7b408520b"
    ["56ca9adaf117e8aae9a3a2e29bbcebf0d8903a99"]="1473d6ad6ff6e5b8419c6b0bc41006b72fd777dd"
    ["511dec657daa60b0f11da20295e2c665ba2c749c"]="26e42e43b393811c176dac651efc5d61e4569305"
    ["93067026c251b100e27805a8b4b9d8f0ae8e291c"]="1d01ee38211f21c67a4311f90315568b3fa530e6"
    ["873749b00e1624df4b01335e0b69102acc185eb9"]="c2f07f4cebf0bfb63e3ca38f811fd5b6112a797e"
    ["06d543b2aab5ea73600ca96497febdad96dc7864"]="796ac7fab2dcad7978a0e8ae48abc9150aba916c"
    ["3a5ed18dc41ff243f3481b6e3cf4770651df0b54"]="22445f5b0d8b6714954b50930c47b8805cf32b98"
    ["4bfa2a72da607752435e432545f98f1a0b3815a8"]="18461b62813166652fd64a96e06237fde81925f7"
    ["8ffe49d91dc0fcd3268ff1afcbc9132d1ae634d1"]="d316d5b2b080346b4bc197ad5ad7994ac043a15d"
    ["1f4491bf5f27f0719ddebdcab6ff4eff56c64b2c"]="a205aa337d808213cf6d4d839b035cde0237b424"
)

declare -A binhash_patch_list=(
    ["cde88ed8fdb2bfeda8de52ef3adede87a72326ef"]="00002dc0: 27000084c0eb4cb9b6000000badd6940\n00003660: 24f0000000e8961e000084c00f84b400"
    ["ec0c3f5bbb857fa84f5d1153545d30d7b408520b"]="00002dc0: 27000084c0eb4cb9b7000000bafd6940\n000036f0: 0000e8291e000084c0eb1eb9ec000000"
    ["1473d6ad6ff6e5b8419c6b0bc41006b72fd777dd"]="00002dc0: 27000084c0eb4cb9b7000000baad6a40\n000036f0: 0000e8291e000084c0eb1eb9ec000000"
    ["26e42e43b393811c176dac651efc5d61e4569305"]="00002dc0: 27000084c0eb4cb9ba000000badf6a40\n00003710: f0000000e8271e000084c0eb1eb9ef00"
    ["1d01ee38211f21c67a4311f90315568b3fa530e6"]="00002dc0: 27000084c0eb4cb9bd000000baf76a40\n00003720: 24f0000000e8261e000084c0eb1eb9f2"
    ["c2f07f4cebf0bfb63e3ca38f811fd5b6112a797e"]="00002dc0: 000084c0eb2141b8c1000000b9586c40\n00003780: 1d000084c0e90d0100009041b8f60000"
    ["796ac7fab2dcad7978a0e8ae48abc9150aba916c"]="000035b0: 74cd4889efe8f623000084c0eb004c8d\n000040a0: fdffff4c89efe80519000084c0eb0048"
    ["22445f5b0d8b6714954b50930c47b8805cf32b98"]="00003850: e7e89a27000084c0eb00488dac249000\n00004340: fdffff4c89efe8a51c000084c0eb0048"
    ["18461b62813166652fd64a96e06237fde81925f7"]="000038e0: e7e89a27000084c0eb00488dac249000\n000043d0: fdffff4c89efe8a51c000084c0eb0048"
    ["d316d5b2b080346b4bc197ad5ad7994ac043a15d"]="00004220: 08fdffffe87722000084c090e9000000\n00004390: ffe80a21000084c090e900000000488b"
    ["a205aa337d808213cf6d4d839b035cde0237b424"]="00004220: 08fdffffe87722000084c090e9000000\n00004390: ffe80a21000084c090e900000000488b"
)

declare -a binpath_list=()

declare -a path_list=(
    "/usr/syno/bin"
    "/volume1/@appstore/VideoStation/bin"
    "/volume2/@appstore/VideoStation/bin"
    "/volume3/@appstore/VideoStation/bin"
    "/volume1/@appstore/MediaServer/bin"
    "/volume2/@appstore/MediaServer/bin"
    "/volume3/@appstore/MediaServer/bin"
    "/volume1/@appstore/SurveillanceStation/bin"
    "/volume2/@appstore/SurveillanceStation/bin"
    "/volume3/@appstore/SurveillanceStation/bin"
    "/volume1/@appstore/CodecPack/bin"
    "/volume2/@appstore/CodecPack/bin"
    "/volume3/@appstore/CodecPack/bin"
    "/volume1/@appstore/AudioStation/bin"
    "/volume2/@appstore/AudioStation/bin"
    "/volume3/@appstore/AudioStation/bin"
)

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
        echo "MD5 mismatch"
    fi

    for ((i = 0; i < ${#hex_values[@]}; i++)); do
        offset=$(( 0x${hex_values[i]} + 0x8000 ))
        value=${values[indices[i]]}
        printf '%s' "$value" | xxd -r -p | dd of="$so" bs=1 seek="$offset" conv=notrunc
        if [[ $? -ne 0 ]]; then
            echo "AME Patch: Error while writing to file!"
        fi
    done

    mkdir -p "$(dirname "${lic}")"
    rm -f "${lic}"
    echo "${content}" >"${lic}"
    
    bin_file="synocodectool"
    conf_file="activation.conf"
    conf_path="/usr/syno/etc/codec"
    conf_string='{"success":true,"activated_codec":["hevc_dec","ac3_dec","h264_dec","h264_enc","aac_dec","aac_enc","mpeg4part2_dec","vc1_dec","vc1_enc"],"token":"123456789987654abc"}'

    function check_path () {
        for i in "${path_list[@]}"; do
            if [ -e "$i/$bin_file" ]; then
                binpath_list+=( "$i/$bin_file" )
            fi
        done
    }

    function patch () {
        local backup_path="${bin_path%??????????????}/backup"
        local synocodectool_hash="$(sha1sum "$bin_path" | cut -f1 -d\ )"
        if [[ "${binhash_version_list[$synocodectool_hash]+isset}" ]] ; then
            local backup_identifier="${synocodectool_hash:0:8}"
            if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
                backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
                if [[ "${binhash_version_list[$backup_hash]+isset}" ]]; then
                    echo "Restored synocodectool and valid backup detected (DSM ${binhash_version_list[$backup_hash]}) . Patching..."
                    echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"                
                    echo "Patched successfully"
                    echo "Creating spoofed activation.conf.."
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
                else
                    echo "Corrupted backup and original synocodectool detected. Overwriting backup..."
                    mkdir -p "$backup_path"
                    cp -p "$bin_path" \
                    "$backup_path/$bin_file.$backup_identifier"
                fi
            else    
                echo "Detected valid synocodectool. Creating backup.."
                mkdir -p "$backup_path"
                cp -p "$bin_path" \
                "$backup_path/$bin_file.$backup_identifier"
                echo "Patching..."
                echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"            
                echo "Patched"
                echo "Creating spoofed activation.conf.."
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
            fi
        elif [[ "${patchhash_binhash_list[$synocodectool_hash]+isset}" ]]; then
            local original_hash="${patchhash_binhash_list[$synocodectool_hash]}"
            local backup_identifier="${original_hash:0:8}"
            if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
                backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
                if [[ "$original_hash"="$backup_hash" ]]; then
                    echo "Valid backup and patched synocodectool detected. Skipping patch."
                else
                    echo "Patched synocodectool and corrupted backup detected. Skipping patch."
                fi
            else
                echo "Patched synocodectool and no backup detected. Skipping patch."
            fi
        else
            echo "Corrupted synocodectool detected. Please use the -r option to try restoring it."
        fi 
    }

    function patch_common () {
        check_path
        if  ! (( ${#binpath_list[@]} )) ; then
            echo "Something went wrong. Could not find synocodectool"
        fi
        for i in "${binpath_list[@]}"; do
            echo -e "Patching $i"
            bin_path="$i"
            patch
        done
    }
    if "$cp_usr_path/bin/synoame-bin-check-license"; then
        echo -e "AME Patch: Downloading Codec!"
        if "$cp_usr_path/bin/synoame-bin-auto-install-needed-codec"; then
            echo "AME Patch: Successful!"
            patch_common
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
    if [ -f "$conf_path/$conf_file" ]; then
        chattr -i "$conf_path/$conf_file"
        rm "$conf_path/$conf_file"
    fi
    if [ -f "$backup_path/$bin_file.$backup_identifier" ]; then
        mv -f "$backup_path/$bin_file.$backup_identifier" "$bin_path"
    fi
    echo "AME Patch: Backup restored!"
    exit 1
fi
exit 0