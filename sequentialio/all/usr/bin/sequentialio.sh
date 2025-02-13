#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

script="Sequential I/O SSD caches"

# Check script is running as root
if [[ $(whoami) != "root" ]]; then
    echo "$script"
    echo "ERROR: This script must be run as sudo or root!"
    exit 1
fi

# Save options used
args=("$@")

# Determine kb value based on the first argument
kb="0"
[[ "$1" == "false" ]] && kb="1024"

# Show options used
[[ ${#args[@]} -gt 0 ]] && echo "Using options: ${args[*]}"

# Get list of volumes with caches
cachelist=$(sysctl dev | grep skip_seq_thresh_kb)
IFS=$'\n' read -r -d '' -a caches <<< "$cachelist"

if [[ ${#caches[@]} -lt 1 ]]; then
    echo "No caches found!" && exit 1
fi

# Process each cache
for c in "${caches[@]}"; do
    volume=$(echo "$c" | cut -d"+" -f2 | cut -d"." -f1)
    sysctl_dev=$(echo "$c" | cut -d"." -f2 | awk '{print $1}')
    key=$(echo "$c" | cut -d"=" -f1 | cut -d" " -f1)

    # Set new cache kb value
    synosetkeyvalue /etc/sysctl.conf "$key" "$kb"
    echo "$kb" > "/proc/sys/dev/${sysctl_dev}/skip_seq_thresh_kb"

    # Check and display the new settings
    check=$(synogetkeyvalue /etc/sysctl.conf "$key")
    case "$check" in
        0) echo "Sequential I/O for $volume cache is Enabled in /etc/sysctl.conf" ;;
        1024) echo "Sequential I/O for $volume cache is Disabled in /etc/sysctl.conf" ;;
        "") echo "Sequential I/O for $volume cache is not set in /etc/sysctl.conf" ;;
        *) echo "Sequential I/O for $volume cache is set to $check in /etc/sysctl.conf" ;;
    esac

    val=$(cat /proc/sys/dev/"${sysctl_dev}"/skip_seq_thresh_kb)
    case "$val" in
        0) echo "Sequential I/O for $volume cache is Enabled in /proc/sys/dev" ;;
        1024) echo "Sequential I/O for $volume cache is Disabled in /proc/sys/dev" ;;
        "") echo "Sequential I/O for $volume cache is not set in /proc/sys/dev" ;;
        *) echo "Sequential I/O for $volume cache is set to $val in /proc/sys/dev" ;;
    esac
done

exit 0