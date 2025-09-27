#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

VENDOR=""                                                                               # str
FAMILY=""                                                                               # str
SERIES="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed -E 's/@ [0-9.]+[[:space:]]*GHz//g' | sed -E 's/ CPU//g' | xargs)"       # str
CORES="$(grep -c 'cpu cores' /proc/cpuinfo 2>/dev/null)"                                # str
SPEED="$(grep -m1 'MHz' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | cut -d. -f1 | xargs)" # int
GOVERNOR="$(cat /proc/cmdline 2>/dev/null | grep -oE 'governor=[^ ]+' | cut -d= -f2 | xargs)" # str
MEV="$(cat "/proc/cmdline" 2>/dev/null | grep -oE 'mev=[^ ]+' | cut -d= -f2 | xargs)" # str
if [ -n "${MEV}" ] && [ "${MEV}" != "physical" ]; then
  SERIES="${SERIES} @ ${MEV}"
elif [ -n "${GOVERNOR}" ]; then
  SERIES="${SERIES} @ ${GOVERNOR}"
fi

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
  if ps -aux | grep -v grep | grep -q "/usr/sbin/cpuinfo" >/dev/null; then
    /usr/bin/pkill -f "/usr/sbin/cpuinfo"
  fi
  [ -f "/etc/nginx/nginx.conf.bak" ] && mv -f /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && mv -f /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
}

if [ "$1" == "-r" ]; then
  restoreCpuinfo
  exit 0
fi

if [ -f "${FILE_GZ}" ]; then
  [ ! -f "${FILE_GZ}.bak" ] && cp -pf "${FILE_GZ}" "${FILE_GZ}.bak"
else
  [ ! -f "${FILE_JS}.bak" ] && cp -pf "${FILE_JS}" "${FILE_JS}.bak"
fi

rm -f "${FILE_JS}" 2>/dev/null
if [ -f "${FILE_GZ}.bak" ]; then
  gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
else
  cp -pf "${FILE_JS}.bak" "${FILE_JS}"
fi

sed -i "s/\(\(,\)\|\((\)\).\.cpu_vendor/\1\"${VENDOR//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_family/\1\"${FAMILY//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_series/\1\"${SERIES//\"/}\"/g" "${FILE_JS}"
sed -i "s/\(\(,\)\|\((\)\).\.cpu_cores/\1\"${CORES//\"/}\"/g" "${FILE_JS}"

CARDN=$(ls -d /sys/class/drm/card* 2>/dev/null | head -1)
if [ -d "${CARDN}" ]; then
  PCIDN="$(awk -F= '/PCI_SLOT_NAME/ {print $2}' "${CARDN}/device/uevent" 2>/dev/null)"
  LNAME="$(lspci -s ${PCIDN:-"99:99.9"} 2>/dev/null | sed "s/.*: //")"
  # LABLE="$(cat "/sys/class/drm/card0/device/label" 2>/dev/null)"
  CLOCK="$(cat "${CARDN}/gt_max_freq_mhz" 2>/dev/null) MHz"
  MEMORY="$(awk '{s=(strtonum($2)-strtonum($1)+1)/1048576} (and(strtonum($3),0x200))&&(and(strtonum($3),0x2000))&&(and(strtonum($3),0x40000))&&s>0{print int(s) " MiB"; exit}' "${CARDN}/device/resource" 2>/dev/null)"
  if [ -n "${LNAME}" ] && [ -n "${CLOCK}" ] && [ -n "${MEMORY}" ]; then
    echo "GPU Info set to: \"${LNAME}\" \"${CLOCK}\" \"${MEMORY}\""
    # t.gpu={};t.gpu.clock=\"455 MHz\";t.gpu.memory=\"8192 MiB\";t.gpu.name=\"Tesla P4\";t.gpu.temperature_c=47;t.gpu.tempwarn=false;
    sed -i "s/t=this.getActiveApi(t);let/t=this.getActiveApi(t);if(!t.gpu){t.gpu={};t.gpu.clock=\"${CLOCK}\";t.gpu.memory=\"${MEMORY}\";t.gpu.name=\"${LNAME}\";}let/g" "${FILE_JS}"
  fi
fi

if [ "${MEV}" = "physical" ]; then
  sed -i "s/_D(\"support_nvidia_gpu\")},/_D(\"support_nvidia_gpu\")||true},/g" "${FILE_JS}"
  sed -i 's/,t,i,s)}/,t,i,e.sys_temp?s+" \| "+this.renderTempFromC(e.sys_temp):s)}/g' "${FILE_JS}"
  sed -i 's/,C,D);/,C,t.gpu.temperature_c?D+" \| "+this.renderTempFromC(t.gpu.temperature_c):D);/g' "${FILE_JS}"
  sed -i 's/_T("rcpower",n),/(typeof _T==="function"?_T("rcpower", n):"rcpower")?e.fan_list?(typeof _T==="function"?_T("rcpower", n):"rcpower")+e.fan_list.map(fan=>` | ${fan} RPM`).join(""):(typeof _T==="function"?_T("rcpower", n):"rcpower"):e.fan_list?e.fan_list.map(fan=>`${fan} RPM`).join(" | "):(typeof _T==="function"?_T("rcpower", n):"rcpower"),/g' "${FILE_JS}"
fi

[ -f "${FILE_GZ}.bak" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

if ! ps aux | grep -v grep | grep -q "/usr/sbin/cpuinfo" >/dev/null; then
  "/usr/sbin/cpuinfo" &
  [ ! -f "/etc/nginx/nginx.conf.bak" ] && cp -pf /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
  sed -i 's|/run/synoscgi.sock;|/run/arc_synoscgi.sock;|g' /etc/nginx/nginx.conf
  [ ! -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -pf /usr/syno/share/nginx/nginx.mustache /usr/syno/share/nginx/nginx.mustache.bak
  sed -i 's|/run/synoscgi.sock;|/run/arc_synoscgi.sock;|g' /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
fi

exit 0