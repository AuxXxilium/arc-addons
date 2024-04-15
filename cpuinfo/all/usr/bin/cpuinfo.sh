#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

VENDOR=""                                                                                     # str
FAMILY=""                                                                                     # str
SERIES="$(echo $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2))"       # str
CORES="$(grep 'cpu cores' /proc/cpuinfo 2>/dev/null | wc -l)"                                 # str
SPEED="$(echo $(grep 'MHz' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | cut -d. -f1))" # int

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

for O in "$@"; do
  case ${O} in
  --vendor=*)
    VENDOR="${O#*=}"
    ;;
  --family=*)
    FAMILY="${O#*=}"
    ;;
  --series=*)
    SERIES="${O#*=}"
    ;;
  --cores=*)
    CORES="${O#*=}"
    ;;
  --speed=*)
    SPEED="${O#*=}"
    ;;
  -r)
    restoreCpuinfo
    exit 0
    ;;
  *)
    echo "[$O] is not a valid option"
    echo "Usage: cpuinfo.sh [OPTIONS]"
    echo "Options:"
    echo "  --vendor=<VENDOR>   Set the CPU vendor"
    echo "  --family=<FAMILY>   Set the CPU family"
    echo "  --series=<SERIES>   Set the CPU series"
    echo "  --cores=<CORES>     Set the number of CPU cores"
    echo "  --speed=<SPEED>     Set the CPU clock speed"
    echo "  -r                  Restore the original cpuinfo"
    echo "  *                   Show this help message and exit"
    exit 0
    ;;
  esac
done

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

sed -i "s/\(\(,\)\|\((\)\).\.cpu_vendor/\1\"${VENDOR}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_family/\1\"${FAMILY}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_series/\1\"${SERIES}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_cores/\1\"${CORES}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_clock_speed/\1${SPEED}/g" "${FILE_JS}"

if [ -f "${FILE_GZ}.bak" ]; then
  gzip -c "${FILE_JS}" >"${FILE_GZ}"
  chmod a+r "${FILE_GZ}"
fi

exit 0
