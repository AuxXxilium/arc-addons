#!/usr/bin/env ash

scriptver="23.6.1"
script=NVMeForce
repo="AuxXxilium/arc-addons"

# Check BASH variable is is non-empty and posix mode is off, else abort with error.
[ "$BASH" ] && ! shopt -qo posix || {
    printf >&2 "This is a bash script, don't run it with sh\n"
    exit 1
}


# Shell Colors
Red='\e[0;31m'      # ${Red}
Cyan='\e[0;36m'     # ${Cyan}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Show script version
echo "$script $scriptver"

# Get DSM major and minor versions
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
dsminor=$(get_key_value /etc.defaults/VERSION minorversion)
if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "1" ]]; then
    dsm72="yes"
elif [[ $dsm -gt "6" ]] && [[ $dsminor -gt "0" ]]; then
    dsm71="yes"
else
    exit
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=$(get_key_value /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n"

# Get script location
source=${BASH_SOURCE[0]}
while [ -L "$source" ]; do # Resolve $source until the file is no longer a symlink
    scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    # If $source was a relative symlink, we need to resolve it 
    # relative to the path where the symlink file was located
    [[ $source != /* ]] && source=$scriptpath/$source
done
scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )

#--------------------------------------------------------------------
# Check there's no active resync

if grep resync /proc/mdstat >/dev/null ; then
    echo "The Synology is currently doing a RAID resync or data scrub!"
    exit
fi

#--------------------------------------------------------------------
# Get list of M.2 drives

getm2info() {
    nvmemodel=$(cat "$1/device/model")
    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading/trailing space
    echo "$2 M.2 $(basename -- "${1}") is $nvmemodel" >&2
    dev="$(basename -- "${1}")"

    if [[ $all != "yes" ]]; then
        # Skip listing M.2 drives detected as active
        if grep -E "active.*${dev}" /proc/mdstat >/dev/null ; then
            echo -e "${Cyan}Skipping drive as it is being used by DSM${Off}" >&2
            echo "" >&2
            #active="yes"
            return
        fi
    fi

    if [[ -e /dev/${dev}p1 ]] && [[ -e /dev/${dev}p2 ]] &&\
            [[ -e /dev/${dev}p3 ]]; then
        echo -e "${Cyan}WARNING Drive has a volume partition${Off}" >&2
        haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ -e /dev/${dev}p1 ]]; then
        echo -e "${Cyan}WARNING Drive has a cache partition${Off}" >&2
        #haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ ! -e /dev/${dev}p1 ]]; then
        echo "No existing partitions on drive" >&2
    fi
    m2list+=("${dev}")
    echo "" >&2
}

for d in /sys/block/*; do
    case "$(basename -- "${d}")" in
        nvme*)  # M.2 NVMe drives (in PCIe card only?)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                getm2info "$d" "NVMe"
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                getm2info "$d" "SATA"
            fi
        ;;
        *) 
          ;;
    esac
done

#echo -e "Inactive M.2 drives found: ${#m2list[@]}\n"
echo -e "Unused M.2 drives found: ${#m2list[@]}\n"

if [[ ${#m2list[@]} == "0" ]]; then exit; fi


#--------------------------------------------------------------------
# Select RAID type (if multiple M.2 drives found)

if [[ ${#m2list[@]} -eq "1" ]]; then
    raidtype="1"
    single="yes"
elif [[ ${#m2list[@]} -gt "1" ]]; then
    raidtype="1"
fi
if [[ $single == "yes" ]]; then
    echo -e "You selected ${Cyan}Single${Off}"
else
    echo -e "You selected ${Cyan}RAID $raidtype${Off}"
fi


#--------------------------------------------------------------------
# Selected M.2 drive functions

getindex(){
    # Get array index from value
    for i in "${!m2list[@]}"; do
        if [[ "${m2list[$i]}" == "${1}" ]]; then
            r="${i}"
        fi
    done
    return "$r"
}


remelement(){
    # Remove selected drive from list of other selectable drives
    if [[ $1 ]]; then
        num="0"
        while [[ $num -lt "${#m2list[@]}" ]]; do
            if [[ ${m2list[num]} == "$1" ]]; then
                # Remove selected drive from m2list array
                unset "m2list[num]"

                # Rebuild the array to remove empty indices
                for i in "${!m2list[@]}"; do
                    tmp_array+=( "${m2list[i]}" )
                done
                m2list=("${tmp_array[@]}")
                unset tmp_array
            fi
            num=$((num +1))
        done
    fi
}


#--------------------------------------------------------------------
# Select first M.2 drive

if [[ $single == "yes" ]]; then
    PS3="Select the M.2 drive: "
else
    PS3="Select the 1st M.2 drive: "
fi
for i in "${!m2list[@]}"; do  # Get array index from element
    if [[ "${m2list[$i]}" == "nvme0n1" ]]; then
        m21="${m2list[i]}"
    fi
done

if [[ $m21 ]]; then
    # Remove selected drive from list of selectable drives
    remelement "$m21"
    # Keep track of many drives user selected
    selected="$((selected +1))"
    echo -e "You selected ${Cyan}$m21${Off}"
fi
echo


#--------------------------------------------------------------------
# Select 2nd M.2 drive (if RAID selected)

if [[ $single != "yes" ]]; then
    if [[ $raidtype == "0" ]] || [[ $raidtype == "1" ]] || [[ $raidtype == "5" ]];
    then
        if [[ ${#m2list[@]} -gt "0" ]]; then
            PS3="Select the 2nd M.2 drive: "
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme1n1" ]]; then
                    m22="${m2list[i]}"
                fi
            done
            if [[ $m22 ]]; then
                # Remove selected drive from list of selectable drives
                remelement "$m22"
                # Keep track of many drives user selected
                selected="$((selected +1))"
                echo -e "You selected ${Cyan}$m22${Off}"
            fi
            echo
        fi
    fi
fi


#--------------------------------------------------------------------
# Select 3rd M.2 drive (if RAID selected)

if [[ $single != "yes" ]] && [[ $Done != "yes" ]]; then
    if [[ $raidtype == "0" ]] || [[ $raidtype == "1" ]] || [[ $raidtype == "5" ]];
    then
        if [[ ${#m2list[@]} -gt "0" ]]; then
            #tmplist="${m2list[@]}"
            for i in "${!m2list[@]}"; do
                tmplist+=( "${m2list[i]}" )
            done
            if [[ $raidtype != "5" ]]; then
                tmplist+=("Done")  
            fi
            PS3="Select the 3rd M.2 drive: "
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme2n1" ]]; then
                    m23="${m2list[i]}"
                fi
            done
            if [[ $m23 ]]; then
                # Remove selected drive from list of selectable drives
                remelement "$m23"
                # Keep track of many drives user selected
                selected="$((selected +1))"
                echo -e "You selected ${Cyan}$m23${Off}"
            fi
            echo
        fi
    fi
fi


#--------------------------------------------------------------------
# Select 4th M.2 drive (if RAID selected)

if [[ $single != "yes" ]] && [[ $Done != "yes" ]]; then
    if [[ $raidtype == "0" ]] || [[ $raidtype == "1" ]] || [[ $raidtype == "5" ]];
    then
        if [[ ${#m2list[@]} -gt "0" ]]; then
            PS3="Select the 4th M.2 drive: "
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme3n1" ]]; then
                    m24="${m2list[i]}"
                fi
            done
            if [[ $m24 ]]; then
                # Remove selected drive from list of selectable drives
                remelement "$m24"
                # Keep track of many drives user selected
                selected="$((selected +1))"
                echo -e "You selected ${Cyan}$m24${Off}"  # debug
            fi
            echo
        fi
    fi
fi

#--------------------------------------------------------------------
# Let user confirm their choices

format="btrfs"

if [[ $format == "btrfs" ]] || [[ $format == "ext4" ]]; then
    formatshow="$format "
fi

if [[ $selected == "4" ]]; then
    echo -e "Ready to create ${Cyan}${formatshow}RAID $raidtype${Off} volume"\
        "group using ${Cyan}$m21${Off}, ${Cyan}$m22${Off},"\
            "${Cyan}$m23${Off} and ${Cyan}$m24${Off}"
elif [[ $selected == "3" ]]; then
    echo -e "Ready to create ${Cyan}${formatshow}RAID $raidtype${Off} volume"\
        "group using ${Cyan}$m21${Off}, ${Cyan}$m22${Off}"\
            "and ${Cyan}$m23${Off}"
elif [[ $selected == "2" ]]; then
    echo -e "Ready to create ${Cyan}${formatshow}RAID $raidtype${Off} volume"\
        "group using ${Cyan}$m21${Off} and ${Cyan}$m22${Off}"
else
    echo -e "Ready to create ${formatshow}volume group on ${Cyan}$m21${Off}"
fi

if [[ $haspartitons == "yes" ]]; then
    echo -e "\n${Red}WARNING${Off} Everything on the selected"\
        "M.2 drive(s) will be deleted."
    exit
fi

sleep 3


#--------------------------------------------------------------------
# Get highest md# mdraid device

# Using "md[0-9]{1,2}" to avoid md126 and md127 etc
lastmd=$(grep -oP "md[0-9]{1,2}" "/proc/mdstat" | sort | tail -1)
nextmd=$((${lastmd:2} +1))
if [[ $nextmd -lt "3" ]]; then
exit
fi
if [[ -z $nextmd ]]; then
    echo -e "${Error}ERROR${Off} Next md number not found!"
    exit 1
else
    echo "Using md$nextmd as it's the next available."
fi


#--------------------------------------------------------------------
# Create Synology partitions on selected M.2 drives

if [[ $dsm == "7" ]]; then
    synopartindex=13  # Syno partition index for NVMe drives can be 12 or 13 or ?
else
    synopartindex=12  # Syno partition index for NVMe drives can be 12 or 13 or ?
fi
if [[ $m21 ]]; then
    echo -e "\nCreating Synology partitions on $m21"
        if ! echo y | synopartition --part /dev/"$m21" "$synopartindex"; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create syno partitions!"
            exit 1
        fi
fi
if [[ $m22 ]]; then
    echo -e "\nCreating Synology partitions on $m22"
        if ! echo y | synopartition --part /dev/"$m22" "$synopartindex"; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create syno partitions!"
            exit 1
        fi
fi
if [[ $m23 ]]; then
    echo -e "\nCreating Synology partitions on $m23"
        if ! echo y | synopartition --part /dev/"$m23" "$synopartindex"; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create syno partitions!"
            exit 1
        fi
fi
if [[ $m24 ]]; then
    echo -e "\nCreating Synology partitions on $m24"
        if ! echo y | synopartition --part /dev/"$m24" "$synopartindex"; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create syno partitions!"
            exit 1
        fi
fi


#--------------------------------------------------------------------
# Create the RAID array
# --level=0 for RAID 0  --level=1 for RAID 1  --level=5 for RAID 5

if [[ $selected == "2" ]]; then
    echo -e "\nCreating the RAID array. This can take an hour..."
        if ! echo y | mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices=2\
            --force /dev/"${m21}"p3 /dev/"${m22}"p3; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create RAID!"
            exit 1
        fi
elif [[ $selected == "3" ]]; then
    echo -e "\nCreating the RAID array. This can take an hour..."
        if ! echo y | mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices=3\
            --force /dev/"${m21}"p3 /dev/"${m22}"p3 /dev/"${m23}"p3; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create RAID!"
            exit 1
        fi
elif [[ $selected == "4" ]]; then
    echo -e "\nCreating the RAID array. This can take an hour..."
        if ! echo y | mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices=4\
            --force /dev/"${m21}"p3 /dev/"${m22}"p3 /dev/"${m23}"p3 /dev/"${m24}"p3; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create RAID!"
            exit 1
        fi
else
    echo -e "\nCreating single drive RAID."
        if ! echo y | mdadm --create /dev/md${nextmd} --level=1 --raid-devices=1\
            --force /dev/"${m21}"p3; then
            echo -e "\n${Error}ERROR 5${Off} Failed to create RAID!"
            exit 1
        fi
fi

# Show resync progress every 5 seconds
if [[ $dryrun == "yes" ]]; then
    echo -ne "      [====>................]  resync = 20%\r"; sleep 1  # dryrun
    echo -ne "      [========>............]  resync = 40%\r"; sleep 1  # dryrun
    echo -ne "      [============>........]  resync = 60%\r"; sleep 1  # dryrun
    echo -ne "      [================>....]  resync = 80%\r"; sleep 1  # dryrun
    echo -ne "      [====================>]  resync = 100%\r\n"        # dryrun
else
    while grep resync /proc/mdstat >/dev/null; do
        # Only multi-drive RAID gets re-synced
        progress="$(grep -E -A 2 active.*nvme /proc/mdstat | grep resync | cut -d\( -f1 )"
        echo -ne "$progress\r"
        sleep 5
    done
    # Show 100% progress
    if [[ $progress ]]; then
        echo -ne "      [====================>]  resync = 100%\r"
    fi
fi


#--------------------------------------------------------------------
# Create Physical Volume and Volume Group with LVM - DSM 7 only

# Create a physical volume (PV) on the partition
if [[ $dsm -gt "6" ]]; then
    echo -e "\nCreating a physical volume (PV) on md$nextmd partition"
    if ! pvcreate -ff /dev/md$nextmd ; then
        echo -e "\n${Error}ERROR 5${Off} Failed to create physical volume!"
        exit 1
    fi
fi

# Create a volume group (VG)
if [[ $dsm -gt "6" ]]; then
    echo -e "\nCreating a volume group (VG) on md$nextmd partition"
    if ! vgcreate vg$nextmd /dev/md$nextmd ; then
        echo -e "\n${Error}ERROR 5${Off} Failed to create volume group!"
        exit 1
    fi
fi

#--------------------------------------------------------------------
# Enable m2 volume support - DSM 7.1 and later only

# Backup synoinfo.conf if needed
if [[ $dsm71 == "yes" ]] || [[ $dsm72 == "yes" ]]; then
    synoinfo="/etc.defaults/synoinfo.conf"
    if [[ ! -f ${synoinfo}.bak ]]; then
        if cp "$synoinfo" "$synoinfo.bak"; then
            echo -e "\nBacked up $(basename -- "$synoinfo")" >&2
        else
            echo -e "\n${Error}ERROR 5${Off} Failed to backup $(basename -- "$synoinfo")!"
            exit 1
        fi
    fi
fi

# Check if m2 volume support is enabled
if [[ $dsm71 == "yes" ]] || [[ $dsm72 == "yes" ]]; then
    smp=support_m2_pool
    setting="$(get_key_value "$synoinfo" "$smp")"
    enabled=""
    if [[ ! $setting ]]; then
        # Add support_m2_pool="yes"
        echo 'support_m2_pool="yes"' >> "$synoinfo"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change support_m2_pool="no" to "yes"
        sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
        enabled="yes"
    elif [[ $setting == "yes" ]]; then
        echo -e "\nM.2 volume support already enabled."
    fi

    # Check if we enabled m2 volume support
    setting="$(get_key_value "$synoinfo" "$smp")"
    if [[ $enabled == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled M.2 volume support."
            exec reboot
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable m2 volume support!"
        fi
    fi
fi

