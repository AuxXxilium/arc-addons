#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

VENDOR=""
FAMILY=""
SERIES="$(echo $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2))"
if [ -z "${SERIES}" ]; then
  SERIES="$(cat /proc/cpuinfo | grep -E "model name" | head -1 | cut -d: -f2)"
fi
CORES="$(grep 'cpu cores' /proc/cpuinfo 2>/dev/null | wc -l)"  
SPEED="$(echo $(grep 'MHz' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | cut -d. -f1))"
if [ -z "${SPEED}"] || [ ${SPEED} -eq 800 ]; then
  SPEED="$(cat /proc/cpuinfo | grep -E "cpu MHz" | head -1 | cut -d: -f2 | cut -d. -f1)"
fi

FILE_JS="/usr/syno/synoman/webman/modules/AdminCenter/admin_center.js"
FILE_GZ="${FILE_JS}.gz"

[ ! -f "${FILE_JS}" -a ! -f "${FILE_GZ}" ] && echo "File ${FILE_JS} does not exist" && exit 0

restoreCpuinfo() {
  if [ -f "${FILE_GZ}.bak" ]; then
    rm -f "${FILE_JS}" "${FILE_GZ}"
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
    chmod a+r "${FILE_JS}" "${FILE_GZ}"
  elif [ -f "${FILE_JS}.bak" ]; then
    mv -f "${FILE_JS}.bak" "${FILE_JS}"
    chmod a+r "${FILE_JS}"
  fi
}

if options="$(getopt -o v:f:s:c:p:rh --long vendor:,family:,series:,cores:,speed:,restore,help -- "$@")"; then
  eval set -- "$options"
  while true; do
    case "${1,,}" in
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
      echo "  -v, --vendor <VENDOR>   Set the CPU vendor"
      echo "  -f, --family <FAMILY>   Set the CPU family"
      echo "  -s, --series <SERIES>   Set the CPU series"
      echo "  -c, --cores <CORES>     Set the number of CPU cores"
      echo "  -p, --speed <SPEED>     Set the CPU clock speed"
      echo "  -r, --restore           Restore the original cpuinfo"
      echo "  -h, --help              Show this help message and exit"
      echo "Example:"
      echo "  cpuinfo.sh -v \"AMD\" -f \"Ryzen\" -s \"Ryzen 7 5800X3D\" -c 64 -p 5200"
      echo "  cpuinfo.sh --vendor \"Intel\" --family \"Core i9\" --series \"i7-13900ks\" --cores 64 --speed 5200"
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
  [ ! -f "${FILE_GZ}.bak" ] && cp -f "${FILE_GZ}" "${FILE_GZ}.bak" && chmod a+r "${FILE_GZ}.bak"
else
  [ ! -f "${FILE_JS}.bak" ] && cp -f "${FILE_JS}" "${FILE_JS}.bak" && chmod a+r "${FILE_JS}.bak"
fi

rm -f "${FILE_JS}"
if [ -f "${FILE_GZ}.bak" ]; then
  gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
else
  cp -f "${FILE_JS}.bak" "${FILE_JS}"
fi

echo "CPU Info set to: \"${VENDOR}\" \"${FAMILY}\" \"${SERIES}\" \"${CORES}\" \"${SPEED}\""

sed -i "s/\(\(,\)\|\((\)\).\.cpu_vendor/\1\"${VENDOR//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_family/\1\"${FAMILY//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_series/\1\"${SERIES//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_cores/\1\"${CORES//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_clock_speed/\1${SPEED//\"/}/g" "${FILE_JS}"

if [ -f "${FILE_GZ}.bak" ]; then
  gzip -c "${FILE_JS}" >"${FILE_GZ}"
  chmod a+r "${FILE_GZ}"
fi

exit 0