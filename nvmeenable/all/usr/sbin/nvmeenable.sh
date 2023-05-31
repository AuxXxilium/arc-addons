#!/usr/bin/env ash

scriptver="23.6.1"
script=NVMeEnable
repo="AuxXxilium/arc-addons"

# Check BASH variable is is non-empty and posix mode is off, else abort with error.
[ "$BASH" ] && ! shopt -qo posix || {
    printf \\a
    printf >&2 "This is a bash script, don't run it with sh\n"
    exit 1
}

#echo -e "bash version: $(bash --version | head -1 | cut -d' ' -f4)\n"  # debug

# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'    # ${Green}
Yellow='\e[0;33m'   # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){
    printf \\a
}

usage(){
    cat <<EOF

Usage: $(basename "$0") [options]

Options:
  -c, --check      Check value in file and backup file
  -r, --restore    Restore backup to undo changes
  -h, --help       Show this help message
  -v, --version    Show the script version
  
EOF
}

scriptversion(){
    cat <<EOF
$script $scriptver - by AuxXxilium

See https://github.com/$repo
EOF
}

# Save options used
args="$@"

# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -a \
    -l check,restore,help,version,log,debug -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -c|--check)         # Check value in file and backup file
                check=yes
                ;;
            -r|--restore)       # Restore backup to undo changes
                restore=yes
                ;;
            -h|--help)          # Show usage options
                usage
                exit
                ;;
            -v|--version)       # Show script version
                scriptversion
                exit
                ;;
            -l|--log)           # Log
                log=yes
                ;;
            -d|--debug)         # Show and log debug info
                debug=yes
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo -e "Invalid option '$1'\n"
                usage "$1"
                ;;
        esac
        shift
    done
else
    echo
    usage
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as root or sudo!"
    exit 1
fi

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
if [[ $dsm -lt "7" ]]; then
    ding
    echo "This script only works for DSM 7."
    exit 1
fi


# Check bc command exists
if ! which bc >/dev/null ; then
    echo -e "${Error}ERROR ${Off} bc command not found!\n"
    exit
fi


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

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

# Show options used
echo "Using options: $args"


#----------------------------------------------------------
# Check file exists

file="/usr/lib/libhwcontrol.so.1"

if [[ ! -f ${file} ]]; then
    ding
    echo -e "${Error}ERROR ${Off} File not found!"
    exit 1
fi


#----------------------------------------------------------
# Restore from backup file

if [[ $restore == "yes" ]]; then
    if [[ -f ${file}.bak ]]; then

        # Check if backup size matches file size
        filesize=$(wc -c "${file}" | awk '{print $1}')
        filebaksize=$(wc -c "${file}.bak" | awk '{print $1}')
        if [[ ! $filesize -eq "$filebaksize" ]]; then
            echo -e "${Yellow}WARNING Backup file size is different to file!${Off}"
            echo "Do you want to restore this backup? [yes/no]:"
            read -r answer
            if [[ $answer != "yes" ]]; then
                exit
            fi
        fi

        # Restore from backup
        if cp "$file".bak "$file" ; then
            echo "Successfully restored from backup."
            rebootmsg
            exit
        else
            ding
            echo -e "${Error}ERROR ${Off} Backup failed!"
            exit 1
        fi
    else
        ding
        echo -e "${Error}ERROR ${Off} Backup file not found!"
        exit 1
    fi
fi


#----------------------------------------------------------
# Backup file

if [[ ! -f ${file}.bak ]]; then
    if cp "$file" "$file".bak ; then
        echo "Backup successful."
    else
        ding
        echo -e "${Error}ERROR ${Off} Backup failed!"
        exit 1
    fi
else
    # Check if backup size matches file size
    filesize=$(wc -c "${file}" | awk '{print $1}')
    filebaksize=$(wc -c "${file}.bak" | awk '{print $1}')
    if [[ ! $filesize -eq "$filebaksize" ]]; then
        echo -e "${Yellow}WARNING Backup file size is different to file!${Off}"
        echo "Maybe you've updated DSM since last running this script?"
        echo "Renaming file.bak to file.bak.old"
        mv "${file}.bak" "$file".bak.old
        if cp "$file" "$file".bak ; then
            echo "Backup successful."
        else
            ding
            echo -e "${Error}ERROR ${Off} Backup failed!"
            exit 1
        fi
    else
        echo "File already backed up."
    fi
fi


#----------------------------------------------------------
# Edit file

findbytes(){
    # Get decimal position of matching hex string
    match=$(od -v -t x1 "$1" |
    sed 's/[^ ]* *//' |
    tr '\012' ' ' |
    grep -b -i -o "$hexstring" |
    #grep -b -i -o "$hexstring ".. |
    sed 's/:.*/\/3/' |
    bc)

    # Convert decimal position of matching hex string to hex
    array=("$match")
    if [[ ${#array[@]} -gt "1" ]]; then
        num="0"
        while [[ $num -lt "${#array[@]}" ]]; do
            poshex=$(printf "%x" "${array[$num]}")
            echo "${array[$num]} = $poshex"  # debug

            seek="${array[$num]}"
            xxd=$(xxd -u -l 12 -s "$seek" "$1")
            #echo "$xxd"  # debug
            printf %s "$xxd" | cut -d" " -f1-7
            bytes=$(printf %s "$xxd" | cut -d" " -f6)
            #echo "$bytes"  # debug

            num=$((num +1))
        done
    elif [[ -n $match ]]; then
        poshex=$(printf "%x" "$match")
        echo "$match = $poshex"  # debug

        seek="$match"
        xxd=$(xxd -u -l 12 -s "$seek" "$1")
        #echo "$xxd"  # debug
        printf %s "$xxd" | cut -d" " -f1-7
        bytes=$(printf %s "$xxd" | cut -d" " -f6)
        #echo "$bytes"  # debug
    else
        bytes=""
    fi
}


# Check value in file and backup file
if [[ $check == "yes" ]]; then
    err=0

    # Check value in file
    echo -e "\nChecking value in file."
    hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
    findbytes "$file"
    if [[ $bytes == "9090" ]]; then
        echo -e "\n${Cyan}File already edited.${Off}"
    else
        hexstring="80 3E 00 B8 01 00 00 00 75 2. 48 8B"
        findbytes "$file"
        if [[ $bytes =~ "752"[0-9] ]]; then
            echo -e "\n${Cyan}File is unedited.${Off}"
        else
            echo -e "\n${Red}hex string not found!${Off}"
            err=1
        fi
    fi

    # Check value in backup file
    if [[ -f ${file}.bak ]]; then
        echo -e "\nChecking value in backup file."
        hexstring="80 3E 00 B8 01 00 00 00 75 2. 48 8B"
        findbytes "${file}.bak"
        if [[ $bytes =~ "752"[0-9] ]]; then
            echo -e "\n${Cyan}Backup file is unedited.${Off}"
        else
            hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
            findbytes "${file}.bak"
            if [[ $bytes == "9090" ]]; then
                echo -e "\n${Red}Backup file has been edited!${Off}"
            else
                echo -e "\n${Red}hex string not found!${Off}"
                err=1
            fi
        fi
    else
        echo "No backup file found."
    fi

    exit "$err"
fi


echo -e "\nChecking file."


# Check if the file is already edited
hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
findbytes "$file"
if [[ $bytes == "9090" ]]; then
    echo -e "\n${Cyan}File already edited.${Off}"
    exit
else

    # Check if the file is okay for editing
    hexstring="80 3E 00 B8 01 00 00 00 75 2. 48 8B"
    findbytes "$file"
    if [[ $bytes =~ "752"[0-9] ]]; then
        echo -e "\nEditing file."
    else
        ding
        echo -e "\n${Red}hex string not found!${Off}"
        exit 1
    fi
fi


# Replace bytes in file
posrep=$(printf "%x\n" $((0x${poshex}+8)))
if ! printf %s "${posrep}: 9090" | xxd -r - "$file"; then
    ding
    echo -e "${Error}ERROR ${Off} Failed to edit file!"
    exit 1
fi


#----------------------------------------------------------
# Check if file was successfully edited

echo -e "\nChecking if file was successfully edited."
hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
findbytes "$file"
if [[ $bytes == "9090" ]]; then
    echo -e "File successfully edited."
    echo -e "\n${Cyan}You can now create your M.2 storage"\
        "pool in Storage Manager.${Off}"
else
    ding
    echo -e "${Error}ERROR ${Off} Failed to edit file!"
    exit 1
fi


#--------------------------------------------------------------------
# Enable m2 volume support - DSM 7.1 and later only

# Backup synoinfo.conf if needed
#if [[ $dsm72 == "yes" ]]; then
#if [[ $dsm71 == "yes" ]]; then
    synoinfo="/etc.defaults/synoinfo.conf"
    if [[ ! -f ${synoinfo}.bak ]]; then
        if cp "$synoinfo" "$synoinfo.bak"; then
            echo -e "\nBacked up $(basename -- "$synoinfo")" >&2
        else
            ding
            echo -e "\n${Error}ERROR 5${Off} Failed to backup $(basename -- "$synoinfo")!"
            exit 1
        fi
    fi
#fi

# Check if m2 volume support is enabled
#if [[ $dsm72 == "yes" ]]; then
#if [[ $dsm71 == "yes" ]]; then
    smp=support_m2_pool
    setting="$(get_key_value "$synoinfo" "$smp")"
    enabled=""
    if [[ ! $setting ]]; then
        # Add support_m2_pool="yes"
        echo 'support_m2_pool="yes"' >> "$synoinfo"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change support_m2_pool="no" to "yes"
        #sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
        synosetkeyvalue "$synoinfo" "$smp" "yes"
        enabled="yes"
    elif [[ $setting == "yes" ]]; then
        echo -e "\nM.2 volume support already enabled."
    fi

    # Check if we enabled m2 volume support
    setting="$(get_key_value "$synoinfo" "$smp")"
    if [[ $enabled == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled M.2 volume support."
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable m2 volume support!"
        fi
    fi
#fi

exit
