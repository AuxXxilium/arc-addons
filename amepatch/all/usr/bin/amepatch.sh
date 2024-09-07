#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
#modelname="$model"


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Get CPU arch and family
arch="$(uname -m)"
family=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/synoinfo.conf platform_name)

# Show DSM full version and model
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo "$model DSM $productversion-$buildnumber$smallfix"

# Show CPU arch and family
echo "CPU $family $arch"

# Check model is supported
spks_list=("x86_64")
if [[ ${spks_list[*]} =~ $arch ]]; then
    cputype="$arch"
elif [[ ${spks_list[*]} =~ $family ]]; then
    cputype="$family"
else
    echo -e "\nUnsupported or unknown CPU family or architecture"
    exit 0
fi
echo "Using CPU type: $cputype"

package_stop() { 
    # $1 is package name
    # $2 is package display name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    timeout 5.0m /usr/syno/bin/synopkg stop "$1" >/dev/null &
    pid=$!
    #string="Stopping ${Cyan}${2}${Off}"
    string="Stopping ${2}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Allow package processes to finish stopping
    wait_status "$1" stop
}

package_start() { 
    # $1 is package name
    # $2 is package display name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    timeout 5.0m /usr/syno/bin/synopkg start "$1" >/dev/null &
    pid=$!
    #string="Starting ${Cyan}${2}${Off}"
    string="Starting ${2}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Allow package processes to finish starting
    wait_status "$1" start
}

package_uninstall() { 
    # $1 is package name
    # $2 is package display name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    /usr/syno/bin/synopkg uninstall "$1" >/dev/null &
    pid=$!
    string="Uninstalling ${Cyan}${2}${Off}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

package_install() { 
    # $1 is package filename
    # $2 is package display name
    # $3 is /volume2 etc
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    #/usr/syno/bin/synopkg install_from_server "$1" "$3" >/dev/null &
    /usr/syno/bin/synopkg install "/tmp/$1" "$3" >/dev/null &
    pid=$!
    if [[ $3 ]]; then
        string="Installing ${Cyan}${2}${Off} on ${Cyan}$3${Off}"
    else
        string="Installing ${Cyan}${2}${Off}"
    fi
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

download_pkg() { 
    # $1 is the package folder name
    # $2 is the package version to download
    # $3 is the package file to download
    local url
    base="https://global.synologydownload.com/download/Package/spk/"
    if [[ ! -f "/tmp/${3:?}" ]]; then
        url="${base}${1:?}/${2:?}/${3:?}"
        echo -e "\nDownloading ${Cyan}${3}${Off}"
        if ! curl -kL -m 30 --connect-timeout 5 "$url" -o "/tmp/$3"; then
            ding
            echo -e "${Error}ERROR 2${Off} Failed to download ${3}!"
            exit 2
        fi
    fi
    if [[ ! -f "/tmp/${3:?}" ]]; then
        ding
        echo -e "${Error}ERROR 3${Off} Failed to download ${3}!"
        exit 3
    else
        echo ""
    fi
}

check_pkg_installed() { 
    # $1 is package
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    /usr/syno/bin/synopkg status "${1:?}" >/dev/null
    code="$?"
    if [[ $code == "255" ]] || [[ $code == "4" ]]; then
        return 1
    else
        return 0
    fi
}

package_is_running() { 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    /usr/syno/bin/synopkg is_onoff "${1}" >/dev/null
    code="$?"
    return "$code"
}

wait_status() { 
    # Wait for package to finish stopping or starting
    # $1 is package
    # $2 is start or stop
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    local num
    if [[ $2 == "start" ]]; then
        state="0"
    elif [[ $2 == "stop" ]]; then
        state="1"
    fi
    if [[ $state == "0" ]] || [[ $state == "1" ]]; then
        num="0"
        package_status "$1"
        while [[ $? != "$state" ]]; do
            sleep 1
            num=$((num +1))
            if [[ $num -gt "20" ]]; then
                break
            fi
            package_status "$1"
        done
    fi
}

# Backup synopackageslimit.conf if needed
if [[ ! -f /etc.defaults/synopackageslimit.conf.bak ]]; then
    cp -p /etc.defaults/synopackageslimit.conf /etc.defaults/synopackageslimit.conf.bak
fi
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf CodecPack "3.1.0-3005"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf CodecPack "3.1.0-3005"

# Get installed AME version
ame_version=$(/usr/syno/bin/synopkg version CodecPack)
if [[ ${ame_version:0:1} -gt "3" ]]; then
    # Uninstall AME v4
    package_uninstall CodecPack "Advanced Media Extensions"
fi

# CodecPack (Advanced Media Extensions)
if ! check_pkg_installed CodecPack && [[ $ame_version != "30.1.0-3005" ]]; then
    download_pkg CodecPack "3.1.0-3005" "CodecPack-${cputype}-3.1.0-3005.spk"
    package_install "CodecPack-${cputype}-3.1.0-3005.spk" "Advanced Media Extensions"
    package_stop CodecPack "Advanced Media Extensions"
    # Prevent package updating and "update available" messages
    echo "Preventing Advanced Media Extensions from auto updating"
    /usr/syno/bin/synosetkeyvalue /var/packages/CodecPack/INFO version "30.1.0-3005"
    package_start CodecPack "Advanced Media Extensions"
    rm -f "/tmp/CodecPack-${cputype}-3.1.0-3005.spk"

    sleep 5

    /usr/syno/etc/rc.sysv/apparmor.sh remove_packages_profile 0 CodecPack

    [ -f "/var/packages/CodecPack/target/apparmor" ] && mv -f "/var/packages/CodecPack/target/apparmor" "/var/packages/CodecPack/target/apparmor.bak"

    ame_path="/var/packages/CodecPack/target/usr"
    values=('669066909066906690' 'B801000000' '30')
    indices=(0 1 1 1 1 2)
    so="$ame_path/lib/libsynoame-license.so"
    so_backup="$ame_path/lib/libsynoame-license.so.orig"
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
        echo "MD5 mismatch - Already patched or unsupported version!"
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
        if "$ame_path/bin/synoame-bin-auto-install-needed-codec"; then
            echo -e "AME Patch: Successful!"
            exit 0
        else
            echo -e "AME Patch: Unsuccessful!"
            exit 1
        fi
    else
        if [ -f "$so_backup" ]; then
            mv -f "$so_backup" "$so"
        fi
        if [ -f "$lic_backup" ]; then
            mv -f "$lic_backup" "$lic"
        fi
        echo -e "AME Patch: Backup restored!"
        exit 1
    fi
else
    echo -e "\nAdvanced Media Extensions${Off} already installed"
    exit 0
fi