#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Variables
TEMP="on"
VENDOR=""
FAMILY=""
SERIES=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
COREC=$(grep -m1 'cpu cores' /proc/cpuinfo | cut -d: -f2 | head -1 | xargs)
THREADC=$(grep -m1 'siblings' /proc/cpuinfo | cut -d: -f2 | head -1 | xargs)
SPEED=$(grep -m1 'MHz' /proc/cpuinfo | cut -d: -f2 | awk '{print int($1)}')
GOVERNOR=$(grep -oP '(?<=\bgovernor=)[^ ]+' /proc/cmdline | xargs)
CORES="Cores: ${COREC:-1} | Threads: ${THREADC:-1} | Governor: ${GOVERNOR:-performance}"
SPEED="${SPEED:-0}"

FILE_JS="/usr/syno/synoman/webman/modules/AdminCenter/admin_center.js"
FILE_GZ="${FILE_JS}.gz"

# Restore original files
restoreCpuinfo() {
  [ -f "${FILE_GZ}.bak" ] && cp -f "${FILE_GZ}.bak" "${FILE_GZ}"
  [ -f "${FILE_JS}.bak" ] && cp -f "${FILE_JS}.bak" "${FILE_JS}"
  [ -f "/etc/nginx/nginx.conf.bak" ] && cp -f "/etc/nginx/nginx.conf.bak" "/etc/nginx/nginx.conf"
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -f "/usr/syno/share/nginx/nginx.mustache.bak" "/usr/syno/share/nginx/nginx.mustache"
  pkill -f "/usr/sbin/synoscgiproxy" 2>/dev/null
}

# Restart services if necessary
restartProxy() {
  if ! ps aux | grep -q "[/]usr/sbin/synoscgiproxy"; then
    "/usr/sbin/synoscgiproxy" &
  fi
}

# Backup files if not already backed up
backupFile() {
  [ -f "$1" ] && [ ! -f "$1.bak" ] && cp -pf "$1" "$1.bak"
}

# Prepare JavaScript file
prepareJavaScript() {
  [ -f "${FILE_GZ}.bak" ] && gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}" || cp -pf "${FILE_JS}.bak" "${FILE_JS}"
}

# Update JavaScript with CPU and GPU info
updateJavaScript() {
  if [ "${TEMP^^}" = "ON" ]; then
    sed -i 's/,t,i,s)}/,t,i,s+" \| "+e.sys_temp+" °C")}/g' "${FILE_JS}"
    sed -i 's/,C,D);/,C,D+" \| "+t.gpu.temperature_c+" °C");/g' "${FILE_JS}"
  fi

  sed -i -e "s/\(\(,\)\|\((\)\).\.cpu_vendor/\1\"${VENDOR//\"/}\"/g" \
         -e "s/\(\(,\)\|\((\)\).\.cpu_family/\1\"${FAMILY//\"/}\"/g" \
         -e "s/\(\(,\)\|\((\)\).\.cpu_series/\1\"${SERIES//\"/}\"/g" \
         -e "s/\(\(,\)\|\((\)\).\.cpu_cores/\1\"${CORES//\"/}\"/g" \
         -e "s/\(\(,\)\|\((\)\).\.cpu_clock_speed/\1${SPEED//\"/}/g" "${FILE_JS}"
}

# GPU Info
updateGPUInfo() {
  CARDN=$(ls -d /sys/class/drm/card* 2>/dev/null | head -1)
  if [ -d "${CARDN}" ]; then
    PCIDN=$(awk -F= '/DEVNAME/ {print $2}' "${CARDN}/device/uevent" 2>/dev/null)
    LNAME=$(lspci -Q -s "${PCIDN:-99:99.9}" 2>/dev/null | sed "s/.*: //")
    CLOCK=$(cat "${CARDN}/gt_max_freq_mhz" 2>/dev/null)
    [ -n "${CLOCK}" ] && CLOCK="${CLOCK} MHz"
    if [ -n "${LNAME}" ] && [ -n "${CLOCK}" ]; then
      echo "GPU Info set to: \"${LNAME}\" \"${CLOCK}\""
      sed -i -e "s/_D(\"support_nvidia_gpu\")},/_D(\"support_nvidia_gpu\")||true},/g" \
             -e "s/t=this.getActiveApi(t);let/t=this.getActiveApi(t);if(!t.gpu){t.gpu={};t.gpu.clock=\"${CLOCK}\";t.gpu.name=\"${LNAME}\";}let/g" "${FILE_JS}"
    fi
  fi
}

# Compress updated JavaScript
compressJavaScript() {
  [ -f "${FILE_GZ}.bak" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"
}

# Restart services if necessary
restartServices() {
  backupFile "/etc/nginx/nginx.conf"
  backupFile "/usr/syno/share/nginx/nginx.mustache"
  sed -i 's|/run/synoscgi.sock;|/run/synoscgi_rr.sock;|' "/etc/nginx/nginx.conf" "/usr/syno/share/nginx/nginx.mustache"
  systemctl reload nginx
}

# Function calls
restoreCpuinfo
restartProxy
backupFile "${FILE_GZ}"
backupFile "${FILE_JS}"
prepareJavaScript
updateJavaScript
updateGPUInfo
compressJavaScript
restartServices

exit 0