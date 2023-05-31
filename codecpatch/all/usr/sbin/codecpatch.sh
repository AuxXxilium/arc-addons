#!/usr/bin/env ash

scriptver="23.6.1"
script=Codecpatch
repo="AuxXxilium/arc-addons"

set -eo pipefail;
shopt -s nullglob;

#variables

bin_file="synocodectool"
conf_file="activation.conf"
conf_path="/usr/syno/etc/codec"
conf_string='{"success":true,"activated_codec":["hevc_dec","ac3_dec","h264_dec","h264_enc","aac_dec","aac_enc","mpeg4part2_dec","vc1_dec","vc1_enc"],"token":"123456789987654abc"}'
opmode="patchhelp"

declare -a binpath_list=()

#functions

spoofed_activation () {
    echo "Creating spoofed activation.conf.."
    if [ ! -e "$conf_path/$conf_file" ] ; then
        mkdir -p $conf_path
        echo "$conf_string" > "$conf_path/$conf_file"
        echo "Spoofed activation.conf created successfully"
        exit 0
    else
        rm "$conf_path/$conf_file"
        echo "$conf_string" > "$conf_path/$conf_file"
        echo "Spoofed activation.conf created successfully"
        exit 0
    fi
}

check_version () {
    local ver="$1"
    for i in "${versions_list[@]}" ; do
        [[ "$i" == "$ver" ]] && return 0
    done ||  return 1
}

patch () {
    local bin_path="$1"
    local backup_path="${bin_path%??????????????}/backup"
    local synocodectool_hash="$(sha1sum "$bin_path" | cut -f1 -d\ )"
    if [[ "${binhash_version_list[$synocodectool_hash]+isset}" ]] ; then
        local backup_identifier="${synocodectool_hash:0:8}"
        if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
            backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
            if [[ "${binhash_version_list[$backup_hash]+isset}" ]]; then
                echo "Restored synocodectool and valid backup detected (DSM ${binhash_version_list[$backup_hash]}). Patching..."
                echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"
                echo "Patched successfully"
                spoofed_activation
            else
                echo "Corrupted backup and original synocodectool detected. Overwriting backup..."
                mkdir -p "$backup_path"
                cp -p "$bin_path" "$backup_path/$bin_file.$backup_identifier"
                exit 0
            fi
        else
            echo "Detected valid synocodectool. Creating backup.."
            mkdir -p "$backup_path"
            cp -p "$bin_path" \
            "$backup_path/$bin_file.$backup_identifier"
            echo "Patching..."
            echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"
            echo "Patched"
            spoofed_activation
        fi
    elif [[ "${patchhash_binhash_list[$synocodectool_hash]+isset}" ]]; then
        local original_hash="${patchhash_binhash_list[$synocodectool_hash]}"
        local backup_identifier="${original_hash:0:8}"
        if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
            backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
            if [[ "$original_hash"="$backup_hash" ]]; then
                echo "Valid backup and patched synocodectool detected. Skipping patch."
                exit 0
            else
                echo "Patched synocodectool and corrupted backup detected. Skipping patch."
                exit 1
            fi
        else
            echo "Patched synocodectool and no backup detected. Skipping patch."
            exit 1
        fi
    else
        echo "Corrupted synocodectool detected. Please use the -r option to try restoring it."
        exit 1
    fi
}

for file in "${binpath_list[@]}"; do
    patch "${file}"
done
