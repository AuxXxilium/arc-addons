#!/usr/bin/env ash

scriptver="23.6.1"
script=CPUInfo
repo="AuxXxilium/arc-addons"

# ==============================================================================
# Location Check
# ==============================================================================

LC_CHK=`cat /etc/synoinfo.conf | grep timezone | awk -F= '{print $2}' | sed 's/"//g'`

# ==============================================================================
# Y or N Function
# ==============================================================================
READ_YN () { # $1:question $2:default
   read -n1 -p "$1" Y_N
    case "$Y_N" in
    y) Y_N="y"
         echo -e "\n" ;;
    n) Y_N="n"
         echo -e "\n" ;;        
    q) echo -e "\n"
       exit 0 ;;
    *) echo -e "\n" ;;
    esac
}
# ==============================================================================
# Color Function
# ==============================================================================
cecho() {
    if [ -n "$3" ]
    then
        case "$3" in
            black  | bk) bgcolor="40";;
            red    |  r) bgcolor="41";;
            green  |  g) bgcolor="42";;
            yellow |  y) bgcolor="43";;
            blue   |  b) bgcolor="44";;
            purple |  p) bgcolor="45";;
            cyan   |  c) bgcolor="46";;
            gray   | gr) bgcolor="47";;
        esac        
    else
        bgcolor="0"
    fi
    code="\033["
    case "$1" in
        black  | bk) color="${code}${bgcolor};30m";;
        red    |  r) color="${code}${bgcolor};31m";;
        green  |  g) color="${code}${bgcolor};32m";;
        yellow |  y) color="${code}${bgcolor};33m";;
        blue   |  b) color="${code}${bgcolor};34m";;
        purple |  p) color="${code}${bgcolor};35m";;
        cyan   |  c) color="${code}${bgcolor};36m";;
        gray   | gr) color="${code}${bgcolor};37m";;
    esac

    text="$color$2${code}0m"
    echo -e "$text"
}
# ==============================================================================
# Process Function
# ==============================================================================
PREPARE_FN () {
    if [ -f "$WORK_DIR/admin_center.js" ] && [ -f "$MWORK_DIR/mobile.js" ]
    then
        if [ "$direct_job" == "y" ]
        then
            cecho r "warning!! Work directly on the original file without backup.\n"
        else
            cd $WORK_DIR
            tar -cf $BKUP_DIR/$TIME/admin_center.tar admin_center.js*
            cd $MWORK_DIR
            tar -cf $BKUP_DIR/$TIME/mobile.tar mobile.js*
            if [ -f "$SWORK_DIR/System.js" ]
            then
                cd $SWORK_DIR
                tar -cf $BKUP_DIR/$TIME/System.tar System.js*
                cp -Rf $SWORK_DIR/System.js $BKUP_DIR/
            fi
        fi
        if [ "$MA_VER" -eq "6" ] && [ "$MI_VER" -ge "2" ]
        then
            mv $WORK_DIR/admin_center.js.gz $BKUP_DIR/
            mv $MWORK_DIR/mobile.js.gz $BKUP_DIR/
            if [ -f "$SWORK_DIR/System.js" ]
            then              
                cp -Rf $SWORK_DIR/System.js $BKUP_DIR/
            fi
	        cd $BKUP_DIR/
            gzip -df $BKUP_DIR/admin_center.js.gz 
            gzip -df $BKUP_DIR/mobile.js.gz
        else
            cp -Rf $WORK_DIR/admin_center.js $BKUP_DIR/
            cp -Rf $MWORK_DIR/mobile.js $BKUP_DIR/
            if [ -f "$SWORK_DIR/System.js" ]
            then            
                cp -Rf $SWORK_DIR/System.js $BKUP_DIR/
            fi
        fi
    else
        COMMENT08_FN
    fi
}

GATHER_FN () {
    cpu_vendor_chk=`cat /proc/cpuinfo | grep model | grep name | sort -u | sed "s/(.)//g" | sed "s/(..)//g" | sed "s/CPU//g" | grep AMD | wc -l`
    if [ "$cpu_vendor_chk" -gt "0" ]
    then
        cpu_vendor="AMD"
    else
        cpu_vendor_chk=`cat /proc/cpuinfo | grep model | grep name | sort -u | sed "s/(.)//g" | sed "s/(..)//g" | sed "s/CPU//g" | grep Intel | wc -l`
        if [ "$cpu_vendor_chk" -gt "0" ]
        then
            cpu_vendor="Intel"
        else    
            cpu_vendor=`cat /proc/cpuinfo | grep Hardware | sort -u | awk '{print $3}' | head -1`
            if [ -z "$cpu_vendor" ]
            then
                cpu_vendor=`cat /proc/cpuinfo grep model | grep name | sort -u | awk '{print $3}' | head -1`
            fi
        fi
    fi
    if [ "$cpu_vendor" == "AMD" ]
    then
        pro_cnt=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk -F: '{print $2}' | sed "s/^\s*AMD//g" | sed "s/^\s//g" | head -1 | grep -wi "PRO" | wc -l`
        if [ "$pro_cnt" -gt 0 ]
        then
            pro_chk="-wi PRO"
        else
            pro_chk="-v PRO"
        fi
        cpu_series=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk -F: '{print $2}' | sed "s/^\s*AMD//g" | sed "s/^\s//g" | head -1 | awk '{ for(i = NF; i > 1; i--) if ($i ~ /^[0-9]/) { for(j=i;j<=NF;j++)printf("%s ", $j);print("\n");break; }}' | sed "s/ *$//g"`
        if  [ -z "$cpu_series" ]
        then
            cpu_series=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk -F: '{print $2}' | sed "s/^\s*AMD//g" | sed "s/^\s//g" | head -1 | awk '{ for(i = NF; i >= 1; i--) if ($i ~ ".*-.*") { print $i }}' | sed "s/ *$//g"`
        fi
        cpu_family=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk -F: '{print $2}' | sed "s/^\s*AMD//g" | sed "s/^\s//g" | head -1 | awk -F"$cpu_series" '{print $1}' | sed "s/ *$//g"`
    elif [ "$cpu_vendor" == "Intel" ]
    then
        cpu_family=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk '{ for(i = 1; i < NF; i++) if ($i ~ /^Intel/) { for(j=i;j<=NF;j++)printf("%s ", $j);printf("\n") }}' | awk -F@ '{ print $1 }' | sed "s/(.)//g" | sed "s/(..)//g" | sed "s/ CPU//g" | awk '{print $2}' | head -1 | sed "s/ *$//g"`
        cpu_series=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk '{ for(i = 1; i < NF; i++) if ($i ~ /^Intel/) { for(j=i;j<=NF;j++)printf("%s ", $j);printf("\n") }}' | awk -F@ '{ print $1 }' | sed "s/(.)//g" | sed "s/(..)//g" | sed "s/ CPU//g" | awk -F"$cpu_family " '{print $2}' | head -1 | sed "s/ *$//g"`
        if [ -z "$cpu_series" ]
        then
            cpu_series="Unknown"
        fi
        if [ "$cpu_family" == "Pentium" ]
        then
            cpu_series_b="$cpu_series"
            cpu_series="$cpu_family $cpu_series"
        else
            m_chk=`echo "$cpu_series" | grep -wi ".* M .*" | wc -l`
            if [ "$m_chk" -gt 0 ]
            then
                cpu_series=`echo "$cpu_series" | sed "s/ M /-/g" | awk '{print $0"M"}'`
            fi
        fi
    else    
        cpu_family=`cat /proc/cpuinfo | grep model | grep name | sort -u | awk -F: '{print $2}' | sed "s/^\s*$cpu_vendor//g" | sed "s/^\s//g" | head -1`
        cpu_series=""    
    fi
###
    cpu_detail=""  
###

    PICNT=`cat /proc/cpuinfo | grep "^physical id" | sort -u | wc -l`
    CICNT=`cat /proc/cpuinfo | grep "^core id" | sort -u | wc -l`
    CCCNT=`cat /proc/cpuinfo | grep "^cpu cores" | sort -u | awk '{print $NF}'`
    CSCNT=`cat /proc/cpuinfo | grep "^siblings" | sort -u | awk '{print $NF}'`
    THCNT=`cat /proc/cpuinfo | grep "^processor" | wc -l`
    ODCNT=`cat /proc/cpuinfo | grep "processor" | wc -l`
    if [ "$THCNT" -gt "0" ] && [ "$PICNT" == "0" ] && [ "$CICNT" == "0" ] && [ "$CCCNT" == "" ] && [ "$CSCNT" == "" ]
    then
        PICNT="1"
        CICNT="$THCNT"
        CCCNT="$THCNT"
        CSCNT="$THCNT"
    fi
    if [ "$PICNT" -gt "1" ]
    then
        TPCNT="$PICNT CPUs"
        TCCNT=`expr $PICNT \* $CCCNT`
    else
        TPCNT="$PICNT CPU"
        TCCNT="$CCCNT"
    fi
    if [ "$TCCNT" -gt "1" ]
    then
        TCCNT="$TCCNT Cores "
    else
        TCCNT="$TCCNT Core "
    fi
    if [ "$CCCNT" -gt "1" ]
    then
        PCCNT="\/$CCCNT Cores "
    else
        PCCNT=" "
    fi    
    if [ "$THCNT" -gt "1" ]
    then
        TTCNT="$THCNT Threads"
    else
        TTCNT="$THCNT Thread"
    fi
    cpu_cores="$TCCNT($TPCNT$PCCNT| $TTCNT)"
}

PERFORM_FN () {
    if [ -f "$BKUP_DIR/admin_center.js" ] && [ -f "$BKUP_DIR/mobile.js" ]
    then    
        if [ "$MA_VER" -ge "6" ]
        then
            if [ "$MA_VER" -ge "7" ]
            then
                cpu_info=`echo "${dt}.cpu_vendor=\"${cpu_vendor}\",${dt}.cpu_family=\"${cpu_family}\",${dt}.cpu_series=\"${cpu_series}\",${dt}.cpu_cores=\"${cpu_cores}\",${dt}.cpu_detail=\"${cpu_detail}\","`
                sed -i "s/Ext.isDefined(${dt}.cpu_vendor/${cpu_info}Ext.isDefined(${dt}.cpu_vendor/g" $BKUP_DIR/admin_center.js
                if [ -f "$BKUP_DIR/System.js" ]
                then
                    cpu_info_s=`echo ${cpu_info} | sed "s/${dt}.cpu/${st}.cpu/g"`
                    sed -i "s/Ext.isDefined(${st}.cpu_vendor/${cpu_info_s}Ext.isDefined(${st}.cpu_vendor/g" $BKUP_DIR/System.js
                fi
            else
                cpu_info=`echo "${dt}.cpu_vendor=\"${cpu_vendor}\";${dt}.cpu_family=\"${cpu_family}\";${dt}.cpu_series=\"${cpu_series}\";${dt}.cpu_cores=\"${cpu_cores}\";${dt}.cpu_detail=\"${cpu_detail}\";"`
                sed -i "s/if(Ext.isDefined(${dt}.cpu_vendor/${cpu_info}if(Ext.isDefined(${dt}.cpu_vendor/g" $BKUP_DIR/admin_center.js
            fi
            sed -i "s/${dt}.cpu_series)])/${dt}.cpu_series,${dt}.cpu_detail)])/g" $BKUP_DIR/admin_center.js
            sed -i "s/{2}\",${dt}.cpu_vendor/{2} {3}\",${dt}.cpu_vendor/g" $BKUP_DIR/admin_center.js
            if [ -f "$BKUP_DIR/System.js" ]
            then
                sed -i "s/${st}.cpu_series)])/${st}.cpu_series,${st}.cpu_detail)])/g" $BKUP_DIR/System.js
                sed -i "s/{2}\",${st}.cpu_vendor/{2} {3}\",${st}.cpu_vendor/g" $BKUP_DIR/System.js                  
            fi
            cpu_info_m=`echo "{name: \"cpu_series\",renderer: function(value){var cpu_vendor=\"${cpu_vendor}\";var cpu_family=\"${cpu_family}\";var cpu_series=\"${cpu_series}\";var cpu_cores=\"${cpu_cores}\";return Ext.String.format('{0} {1} {2} [ {3} ]', cpu_vendor, cpu_family, cpu_series, cpu_cores);},label: _T(\"status\", \"cpu_model_name\")},"`
            sed -i "s/\"ds_model\")},/\"ds_model\")},${cpu_info_m}/g" $BKUP_DIR/mobile.js
        else
            if [ "$MI_VER" -gt "0" ]
            then
                cpu_info=`echo "${dt}.cpu_vendor=\"${cpu_vendor}\";${dt}.cpu_family=\"${cpu_family}\";${dt}.cpu_series=\"${cpu_series}\";${dt}.cpu_cores=\"${cpu_cores}\";"`
            else
                cpu_info=`echo "${dt}.cpu_vendor=\"${cpu_vendor}\";${dt}.cpu_family=\"${cpu_family} ${cpu_series}\";${dt}.cpu_cores=\"${cpu_cores}\";"`
            fi
            sed -i "s/if(Ext.isDefined(${dt}.cpu_vendor/${cpu_info}if(Ext.isDefined(${dt}.cpu_vendor/g" $BKUP_DIR/admin_center.js
        fi
    else
        COMMENT08_FN
    fi
}

APPLY_FN () {
    if [ -f "$BKUP_DIR/admin_center.js" ] && [ -f "$BKUP_DIR/mobile.js" ]
    then    
        cp -Rf $BKUP_DIR/admin_center.js $WORK_DIR/
        cp -Rf $BKUP_DIR/mobile.js $MWORK_DIR/
        if [ -f "$BKUP_DIR/System.js" ]
        then
            cp -Rf $BKUP_DIR/System.js $SWORK_DIR/
            rm -rf $BKUP_DIR/System.js
        fi     
        if [ "$MA_VER" -eq "6" ] && [ "$MI_VER" -lt "2" ]
        then
            rm -rf $BKUP_DIR/admin_center.js
            rm -rf $BKUP_DIR/mobile.js   
        else
            gzip -f $BKUP_DIR/admin_center.js
            gzip -f $BKUP_DIR/mobile.js
            mv $BKUP_DIR/admin_center.js.gz $WORK_DIR/
            mv $BKUP_DIR/mobile.js.gz $MWORK_DIR/        
        fi
    else
        COMMENT08_FN
    fi        
}

RERUN_FN () {
    if [ "$1" == "redo" ]
    then
        ls -l $BKUP_DIR/ | grep ^d | grep -v "$BL_CHK" | awk '{print "rm -rf '$BKUP_DIR'/"$9}' | sh
        GATHER_FN
        if [ -f "$WORK_DIR/admin_center.js" ] && [ -f "$MWORK_DIR/mobile.js" ]
        then
            if [ "$MA_VER" -ge "7" ]
            then
                info_cnt=`cat $WORK_DIR/admin_center.js | egrep "${dt}.model\]\),Ext.isDefined\(${dt}.cpu_vendor" | wc -l`
                if [ -f "$BKUP_DIR/System.js" ]
                then
                    info_cnt_s=`cat $WORK_DIR/admin_center.js | egrep "${st}.model\]\),Ext.isDefined\(${st}.cpu_vendor" | wc -l`
                fi                
            else
                info_cnt=`cat $WORK_DIR/admin_center.js | egrep ".model\]\);if\(Ext.isDefined|.model\]\)\}if\(Ext.isDefined" | wc -l`              
            fi
            info_cnt_m=`cat $MWORK_DIR/mobile.js | grep "ds_model\")},{name:\"ram_size" | wc -l`
            if [ "$info_cnt" -eq "0" ] && [ "$info_cnt_m" -eq "0" ]
            then
                ODCNT_CHK=`cat $WORK_DIR/admin_center.js | grep "cpu_cores=\"$ODCNT\"" | wc -l`
                if [ "$ODCNT_CHK" -gt "0" ]
                then
                    cpu_cores="$ODCNT"
                fi                        
                if [ "$MA_VER" -ge "6" ]
                then
                    if [ "$MA_VER" -ge "7" ]
                    then
                        cpu_info="${dt}.cpu_vendor=\\\"${cpu_vendor}\\\",${dt}.cpu_family=\\\"${cpu_family}\\\",${dt}.cpu_series=\\\"${cpu_series}\\\",${dt}.cpu_cores=\\\"${cpu_cores}\\\",${dt}.cpu_detail=\\\"${cpu_detail}\\\","
                        cpu_info_s="${st}.cpu_vendor=\\\"${cpu_vendor}\\\",${st}.cpu_family=\\\"${cpu_family}\\\",${st}.cpu_series=\\\"${cpu_series}\\\",${st}.cpu_cores=\\\"${cpu_cores}\\\",${st}.cpu_detail=\\\"${cpu_detail}\\\","
                    else
                        cpu_info="${dt}.cpu_vendor=\\\"${cpu_vendor}\\\";${dt}.cpu_family=\\\"${cpu_family}\\\";${dt}.cpu_series=\\\"${cpu_series}\\\";${dt}.cpu_cores=\\\"${cpu_cores}\\\";${dt}.cpu_detail=\\\"${cpu_detail}\\\";"
                    fi
                    sed -i "s/${cpu_info}//g" $WORK_DIR/admin_center.js
                    sed -i "s/${dt}.cpu_detail)])/)])/g" $WORK_DIR/admin_center.js
                    sed -i "s/{2} {3}\",${dt}.cpu_vendor/{2}\",${dt}.cpu_vendor/g" $WORK_DIR/admin_center.js

                    ODCNT_CHK=`cat $MWORK_DIR/mobile.js | grep "cpu_cores=\"$ODCNT\"" | wc -l`
                    if [ "$ODCNT_CHK" -gt "0" ]
                    then
                        cpu_cores="$ODCNT"
                    fi                    

                    cpu_info_m="{name: \\\"cpu_series\\\",renderer: function(value){var cpu_vendor=\\\"${cpu_vendor}\\\";var cpu_family=\\\"${cpu_family}\\\";var cpu_series=\\\"${cpu_series}\\\";var cpu_cores=\\\"${cpu_cores}\\\";return Ext.String.format('{0} {1} {2} [ {3} ]', cpu_vendor, cpu_family, cpu_series, cpu_cores);},label: _T(\\\"status\\\", \\\"cpu_model_name\\\")},"
                    sed -i "s/${cpu_info_m}//g" $MWORK_DIR/mobile.js                    
                    if [[ "$MA_VER" -eq "6" && "$MI_VER" -ge "2" ]] || [ "$MA_VER" -eq "7" ]
                    then
                        cp -Rf $WORK_DIR/admin_center.js $WORK_DIR/admin_center.js.1
                        cp -Rf $MWORK_DIR/mobile.js $MWORK_DIR/mobile.js.1
                        gzip -f $WORK_DIR/admin_center.js
                        gzip -f $MWORK_DIR/mobile.js
                        mv $WORK_DIR/admin_center.js.1 $WORK_DIR/admin_center.js
                        mv $MWORK_DIR/mobile.js.1 $MWORK_DIR/mobile.js
                    fi
                else
                    if [ "$MI_VER" -gt "0" ]
                    then
                        cpu_info="${dt}.cpu_vendor=\\\"${cpu_vendor}\\\";${dt}.cpu_family=\\\"${cpu_family}\\\";${dt}.cpu_series=\\\"${cpu_series}\\\";${dt}.cpu_cores=\\\"${cpu_cores}\\\";"
                    else
                        cpu_info="${dt}.cpu_vendor=\\\"${cpu_vendor}\\\";${dt}.cpu_family=\\\"${cpu_family} ${cpu_series}\\\";${dt}.cpu_cores=\\\"${cpu_cores}\\\";"
                    fi
                    sed -i "s/${cpu_info}//g" $WORK_DIR/admin_center.js
                fi
            fi
        else
            COMMENT08_FN
        fi    
    fi
}

EXEC_FN () {
if [ -d $WORK_DIR ]
then
    Y_N="y"
    : '
    READ_YN "Auto Excute, If you select n, proceed interactively  (Cancel : q) [y/n] : "
    ' :
    if [ "$Y_N" == "y" ]
    then
        mkdir -p $BKUP_DIR/$TIME

        PREPARE_FN

        GATHER_FN

        PERFORM_FN

        APPLY_FN
    fi
fi
}

COMMENT03_FN () {
    echo -e "There is a history of running the same version. Please run again select 2) redo .\n"
    exit 0
}

COMMENT04_FN () {
    echo -e "Do not restore to source when installing a higher version. Contiue...\n"
}

COMMENT05_FN () {
    echo -e "You have verified and installed the previous version. Contiue...\n"
}

COMMENT06_FN () {
    echo -e "Problem and exit. Please run again after checking."
    exit 0    
}

COMMENT07_FN () {
    echo -e "No execution history at this version. Please go back to the first run."
    exit 0
}

COMMENT08_FN () {
    echo -e "The target file(location) does not exist. Please run again after checking."
    exit 0
}

COMMENT09_FN () {
    if [ -f "$SWORK_DIR/System.js" ]
    then
        echo -e "If you use Surveillance Studio, it also applies to Surveillance Studio System Information."
    fi
    echo -e "The operation is complete!! It takes about 1-2 minutes to apply, \n(Please refresh the DSM page with F5 or after logout/login and check the information.)"
    exit 0
}

COMMENT10_FN () {
    echo -e "Only y / n / q can be input. Please proceed again."
    exit 0
}

# ==============================================================================
# Main Progress
# ==============================================================================
clear
WORK_DIR="/usr/syno/synoman/webman/modules/AdminCenter"
SWORK_DIR="/var/packages/SurveillanceStation/target/ui/modules/System"
MWORK_DIR="/usr/syno/synoman/mobile/ui"
BKUP_DIR="/root/Xpenology_backup"
VER_DIR="/etc.defaults"
 
cecho c "DSM CPU Information Change Tool ver. \033[0;31m"$scriptver"\033[00m\n"

if [ -d "$VER_DIR" ]
then
    VER_FIL="$VER_DIR/VERSION"
else
    VER_FIL="/etc/VERSION"
fi

if [ -f "$VER_FIL" ]
then
    MA_VER=`cat $VER_FIL | grep majorversion | awk -F \= '{print $2}' | sed 's/\"//g'`
    MI_VER=`cat $VER_FIL | grep minorversion | awk -F \= '{print $2}' | sed 's/\"//g'`
    PD_VER=`cat $VER_FIL | grep productversion | awk -F \= '{print $2}' | sed 's/\"//g'`
    BL_NUM=`cat $VER_FIL | grep buildnumber | awk -F \= '{print $2}' | sed 's/\"//g'`    
    BL_FIX=`cat $VER_FIL | grep smallfixnumber | awk -F \= '{print $2}' | sed 's/\"//g'`
    if [ "$BL_FIX" -gt "0" ]
    then
        BL_UP="Update $BL_FIX"
    else
        BL_UP=""
    fi
else
    COMMENT08_FN
fi

BL_CHK=$BL_NUM$BL_FIX
TIME=`date +%Y%m%d%H%M%S`"_"$BL_CHK
STIME="$TIME"

if [ "$MA_VER" -ge "6" ]
then
    if [ "$MA_VER" -ge "7" ]
    then
        dt=t
        st=e        
    else
        if [ "$BL_NUM" -ge "24922" ]
        then
            if [ "$BL_NUM" -ge "25423" ]
            then
                dt=g
            else
                dt=h
            fi
        else
            dt=f
        fi
    fi
else
    dt=b
fi

EXEC_FN