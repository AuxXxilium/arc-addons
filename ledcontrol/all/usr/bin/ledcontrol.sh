#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

UGREEN_LEDS_CLI="/usr/bin/ugreen_leds_cli"
SMARTCTL="/usr/bin/smartctl"
HDPARM="/usr/bin/hdparm"
CONFIG_FILE="/usr/bin/led.conf"


# Funktion, um den SMART-Status einer Festplatte zu überprüfen
function check_smart_status() {
    local device=$1
    smartctl -H -n standby $device | grep -q "PASSED"
    return $?
}

# Funktion, um den Power-Status einer Festplatte zu überprüfen, ohne sie aufzuwecken
function check_power_status() {
    local device=$1
    local status=$(hdparm -C $device | grep -oP '(?<=drive state is: ).*')
    echo $status
}

# Funktion, um den Load Average-Wert zu ermitteln
function get_load_average() {
    load_average=$(uptime | awk -F'[a-z]:' '{print $2}' | awk -F',' '{print $1}' | tr -d '[:space:]' | awk -F'.' '{print $1}')
    echo $load_average
}

# Funktion, um zu überprüfen, ob ein Netzwerkinterface verbunden ist
function check_network_interface() {
    local interface=$1
    ip link show dev $interface | grep -q "state UP"
    return $?
}

# Funktion, um die aktuelle Helligkeit basierend auf der Konfigurationsdatei zu ermitteln
function get_brightness() {
    local current_time=$(date +%H:%M)
    local night_start=$(grep -Po '(?<=night_start=).*' $CONFIG_FILE)
    local night_end=$(grep -Po '(?<=night_end=).*' $CONFIG_FILE)
    local day_brightness=$(grep -Po '(?<=day_brightness=).*' $CONFIG_FILE)
    local night_brightness=$(grep -Po '(?<=night_brightness=).*' $CONFIG_FILE)

    if [[ "$current_time" > "$night_start" || "$current_time" < "$night_end" ]]; then
        echo $night_brightness
    else
        echo $day_brightness
    fi
}

if [ "${1}" = "on" ]; then
    echo "Enable Ugreen LED"
    $UGREEN_LEDS_CLI all -on -color 255 255 255 -brightness 65
elif [ "${1}" = "off" ]; then
    echo "Disable Ugreen LED"
    $UGREEN_LEDS_CLI all -off
elif [ "${1}" = "nic" ]; then
    # Get Brightness
    brightness=$(get_brightness)
    # NIC Status
    interface_up=0
    interfaces=($(ls /sys/class/net/ 2>/dev/null | grep eth))

    for interface in "${interfaces[@]}"; do
        if check_network_interface $interface; then
            interface_up=1
            break
        fi
    done

    if [[ $interface_up -eq 1 ]]; then
        $UGREEN_LEDS_CLI netdev -on -color 0 255 0 -brightness $brightness > /dev/null 2>&1
    fi
elif [ "${1}" = "disk" ]; then
    # Get Brightness
    brightness=$(get_brightness)
    # Get Disks
    devices=($(ls -d /dev/sata[1-9] 2>/dev/null))
    # bootdisk=$(cat /usr/addons/bootdisk)
    # Disks Smart Check
    for i in "${!devices[@]}"; do
        # [ "${devices[$i]}" = "/dev/${bootdisk}" ] && continue
        device=${devices[$i]}
        disk_number=$((i + 1))  # Disknummer für die LED-Steuerung (disk1, disk2, etc.)
        color="0 255 0"  # Standardfarbe grün
        
        if check_smart_status $device; then
            color="0 255 0"  # Grün
        else
            color="255 0 0"  # Rot
        fi
        
        power_status=$(check_power_status $device)
        
        case $power_status in
            "unknown")
                $UGREEN_LEDS_CLI disk$disk_number -on -color $color -brightness $brightness > /dev/null 2>&1
                ;;
            "active/idle")
                $UGREEN_LEDS_CLI disk$disk_number -blink 500 500 -color $color -brightness $brightness > /dev/null 2>&1
                ;;
            "standby")
                $UGREEN_LEDS_CLI disk$disk_number -breath 1000 1000 -color $color -brightness $brightness > /dev/null 2>&1
                ;;
            *)
                $UGREEN_LEDS_CLI disk$disk_number -on -color $color -brightness $brightness > /dev/null 2>&1
                ;;
        esac
    done
elif [ "${1}" = "cpu" ]; then
    # Get Brightness
    brightness=$(get_brightness)
    # CPU Load Average
    load_average=$(get_load_average)
    if [ $load_average -lt 1 ]; then
        color="0 255 0"  # Grün
    elif [ $load_average -lt 2 ]; then
        color="127 255 0"  # Gelbgrün
    elif [ $load_average -lt 3 ]; then
        color="255 255 0"  # Gelb
    elif [ $load_average -lt 4 ]; then
        color="255 127 0"  # Orange
    elif [ $load_average -lt 5 ]; then
        color="255 0 0"  # Rot
    else
        color="255 0 0"  # Rot (schnelleres Blinken)
    fi
    $UGREEN_LEDS_CLI power -color $color -brightness $brightness > /dev/null 2>&1
fi
exit 0