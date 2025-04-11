#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

TEMP="on"
VENDOR=""                                                                               # str
FAMILY=""                                                                               # str
SERIES="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"       # str
CORES="$(grep -c 'cpu cores' /proc/cpuinfo 2>/dev/null)"                                # str
SPEED="$(grep -m1 'MHz' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | cut -d. -f1 | xargs)" # int

FILE_JS="/usr/syno/synoman/webman/modules/AdminCenter/admin_center.js"
FILE_GZ="${FILE_JS}.gz"

if [ ! -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ]; then
  echo "File ${FILE_JS} does not exist"
  exit 0
fi

restoreCpuinfo() {
  if [ -f "${FILE_GZ}.bak" ]; then
    rm -f "${FILE_JS}" "${FILE_GZ}"
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  elif [ -f "${FILE_JS}.bak" ]; then
    mv -f "${FILE_JS}.bak" "${FILE_JS}"
  fi
  if ps aux | grep -v grep | grep "/usr/sbin/synoscgiproxy" >/dev/null; then
    pkill -f "/usr/sbin/synoscgiproxy"
  fi
  [ -f "/etc/nginx/nginx.conf.bak" ] && mv -f /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && mv -f /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
}

if options="$(getopt -o t:v:f:s:c:p:rh --long temp:,vendor:,family:,series:,cores:,speed:,restore,help -- "$@")"; then
  eval set -- "$options"
  while true; do
    case "${1,,}" in
    -t | --temp)
      TEMP="${2}"
      shift 2
      ;;
    -v | --vendor)
      VENDOR="${2}"
      shift 2
      ;;
    -f | --family)
      FAMILY="${2}"
      shift 2
      ;;
    -s | --series)
      SERIES="${2}"
      shift 2
      ;;
    -c | --cores)
      CORES="${2}"
      shift 2
      ;;
    -p | --speed)
      SPEED="${2}"
      shift 2
      ;;
    -r | --restore)
      restoreCpuinfo
      exit 0
      ;;
    -h | --help)
      echo "Usage: cpuinfo.sh [OPTIONS]"
      echo "Options:"
      echo "  -t, --temp   <on/off>   Set the CPU&GPU temperature display"
      echo "  -v, --vendor <VENDOR>   Set the CPU vendor"
      echo "  -f, --family <FAMILY>   Set the CPU family"
      echo "  -s, --series <SERIES>   Set the CPU series"
      echo "  -c, --cores <CORES>     Set the number of CPU cores"
      echo "  -p, --speed <SPEED>     Set the CPU clock speed"
      echo "  -r, --restore           Restore the original cpuinfo"
      echo "  -h, --help              Show this help message and exit"
      echo "Example:"
      echo "  cpuinfo.sh -t \"on\" -v \"AMD\" -f \"Ryzen\" -s \"Ryzen 7 5800X3D\" -c 64 -p 5200"
      echo "  cpuinfo.sh -t \"on\" --vendor \"Intel\" --family \"Core i9\" --series \"i7-13900ks\" --cores 64 --speed 5200"
      echo "  cpuinfo.sh --restore"
      echo "  cpuinfo.sh --help"
      exit 0
      ;;
    --)
      break
      ;;
    *)
      echo "Invalid option: $OPTARG" >&2
      ;;
    esac
  done
else
  echo "getopt error"
  exit 1
fi

CORES="${CORES:-1}"
SPEED="${SPEED:-0}"

if [ -f "${FILE_GZ}" ]; then
  [ ! -f "${FILE_GZ}.bak" ] && cp -pf "${FILE_GZ}" "${FILE_GZ}.bak"
else
  [ ! -f "${FILE_JS}.bak" ] && cp -pf "${FILE_JS}" "${FILE_JS}.bak"
fi

rm -f "${FILE_JS}"
if [ -f "${FILE_GZ}.bak" ]; then
  gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
else
  cp -pf "${FILE_JS}.bak" "${FILE_JS}"
fi

echo "CPU Info set to: \"TEMP:${TEMP}\" \"${VENDOR}\" \"${FAMILY}\" \"${SERIES}\" \"${CORES}\" \"${SPEED}\""

if [ "${TEMP^^}" = "ON" ]; then
  sed -i 's/,t,i,s)}/,t,i,s+" \| "+e.sys_temp+" °C")}/g' "${FILE_JS}"
  sed -i 's/,C,D);/,C,D+" \| "+t.gpu.temperature_c+" °C");/g' "${FILE_JS}"
fi

sed -i "s/\(\(,\)\|\((\)\).\.cpu_vendor/\1\"${VENDOR//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_family/\1\"${FAMILY//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_series/\1\"${SERIES//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_cores/\1\"${CORES//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_clock_speed/\1${SPEED//\"/}/g" "${FILE_JS}"

CARDN=$(ls -d /sys/class/drm/card* 2>/dev/null | head -1)
if [ -d "${CARDN}" ]; then
  PCIDN="$(awk -F= '/DEVNAME/ {print $2}' "${CARDN}/device/uevent" 2>/dev/null)"
  LNAME="$(lspci -Q -s ${PCIDN:-"99:99.9"} 2>/dev/null | sed "s/.*: //")"
  # LABLE="$(cat "/sys/class/drm/card0/device/label" 2>/dev/null)"
  CLOCK="$(cat "${CARDN}/gt_max_freq_mhz" 2>/dev/null)"
  [ -n "${CLOCK}" ] && CLOCK="${CLOCK} MHz"
  if [ -n "${LNAME}" ] && [ -n "${CLOCK}" ]; then
    echo "GPU Info set to: \"${LNAME}\" \"${CLOCK}\""
    sed -i "s/_D(\"support_nvidia_gpu\")},/_D(\"support_nvidia_gpu\")||true},/g" "${FILE_JS}"
    # t.gpu={};t.gpu.clock=\"455 MHz\";t.gpu.memory=\"8192 MiB\";t.gpu.name=\"Tesla P4\";t.gpu.temperature_c=47;t.gpu.tempwarn=false;
    sed -i "s/t=this.getActiveApi(t);let/t=this.getActiveApi(t);if(!t.gpu){t.gpu={};t.gpu.clock=\"${CLOCK}\";t.gpu.name=\"${LNAME}\";}let/g" "${FILE_JS}"
  fi
fi

[ -f "${FILE_GZ}.bak" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

if "/usr/sbin/synoscgiproxy" -t >/dev/null 2>&1; then
  if ! ps aux | grep -v grep | grep "/usr/sbin/synoscgiproxy" >/dev/null; then
    "/usr/sbin/synoscgiproxy" &
    [ ! -f "/etc/nginx/nginx.conf.bak" ] && cp -pf /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    sed -i 's|/run/synoscgi.sock;|/run/synoscgi_rr.sock;|' /etc/nginx/nginx.conf
    [ ! -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -pf /usr/syno/share/nginx/nginx.mustache /usr/syno/share/nginx/nginx.mustache.bak
    sed -i 's|/run/synoscgi.sock;|/run/synoscgi_rr.sock;|' /usr/syno/share/nginx/nginx.mustache
    systemctl reload nginx
  fi
else
  if ps aux | grep -v grep | grep "/usr/sbin/synoscgiproxy" >/dev/null; then
    pkill -f "/usr/sbin/synoscgiproxy"
  fi
  [ -f "/etc/nginx/nginx.conf.bak" ] && mv -f /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && mv -f /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
fi

exit 0