#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and 007revad <https://github.com/007revad>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

script="Sequential I/O SSD caches"
color=no

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "$script"
    echo -e "ERROR This script must be run as sudo or root!"
    exit 1
fi

# Save options used
args=("$@")

if [[ -z "$1" ]]; then
    kb="0"
elif [[ "$1" == "true" ]]; then
    kb="0"
elif [[ "$1" == "false" ]]; then
    kb="1024"
fi

# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo "Using options: ${args[*]}"
fi


# Get list of volumes with caches
cachelist=("$(sysctl dev | grep skip_seq_thresh_kb)")
IFS=$'\n' caches=($(sort <<<"${cachelist[*]}")); unset IFS


if [[ ${#caches[@]} -lt "1" ]]; then
    echo "No caches found!" && exit 1
fi


# Get caches' current setting 
for c in "${caches[@]}"; do
    volume="$(echo "$c" | cut -d"+" -f2 | cut -d"." -f1)"
    kbs="$(echo "$c" | cut -d"=" -f2 | awk '{print $1}')"
    volumes+=("${volume}|$kbs")

    sysctl_dev="$(echo "$c" | cut -d"." -f2 | awk '{print $1}')"
    sysctl_devs+=("$sysctl_dev")
done


# Show cache volumes and current setting
if [[ ${#volumes[@]} -gt 0 ]]; then
    IFS="|" read -r cachevol setting <<< "${volumes}"
    cachevols=("$cachevol")
fi


for v in "${sysctl_devs[@]}"; do
    for c in "${cachevols[@]}"; do
        if [[ $v =~ "$c" ]]; then
            cachevol="$c"

            # Get cache's key name
            cacheval="$(sysctl dev | grep skip_seq_thresh_kb | grep "$cachevol")"
            key="$(echo "$cacheval" | cut -d"=" -f1 | cut -d" " -f1)"

            # Set new cache kb value
            val="$(synosetkeyvalue /etc/sysctl.conf "$key")"
            if [[ $val != "$kb" ]]; then
                synosetkeyvalue /etc/sysctl.conf "$key" "$kb"
            fi

            if echo "$v" | grep "$cachevol" >/dev/null; then
                echo "$kb" > "/proc/sys/dev/${v}/skip_seq_thresh_kb"
            fi

            # Check we set key value
            check="$(synogetkeyvalue /etc/sysctl.conf "$key")"
            if [[ "$check" == "0" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Green}Enabled${Off} in /etc/sysctl.conf"
            elif [[ "$check" == "1024" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Red}Disabled${Off} in /etc/sysctl.conf"
            elif [[ -z "$check" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Red}not set${Off} in /etc/sysctl.conf"
            else
                echo -e "Sequential I/O for $cachevol cache is set to ${Cyan}$check${Off} in /etc/sysctl.conf"
            fi

            # Check we set proc/sys/dev
            val="$(cat /proc/sys/dev/"${v}"/skip_seq_thresh_kb)"
            if [[ "$val" == "0" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Green}Enabled${Off} in /proc/sys/dev\n"
            elif [[ "$val" == "1024" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Red}Disabled${Off} in /proc/sys/dev\n"
            elif [[ -z "$val" ]]; then
                echo -e "Sequential I/O for $cachevol cache is ${Red}not set${Off} in /proc/sys/dev\n"
            else
                echo -e "Sequential I/O for $cachevol cache is set to ${Cyan}$val${Off} in /proc/sys/dev\n"
            fi
        fi
    done
done

exit 0