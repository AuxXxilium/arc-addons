#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

VENDOR=""                                                                               # str
FAMILY=""                                                                               # str
SERIES="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed -E 's/@ [0-9.]+[[:space:]]*GHz//g' | sed -E 's/ CPU//g' | xargs)"       # str
CORES="$(cat /sys/devices/system/cpu/cpu[0-9]*/topology/{core_cpus_list,thread_siblings_list} | sort -u | wc -l 2>/dev/null)"                                # str
MEV="$(cat "/proc/cmdline" 2>/dev/null | grep -oE 'mev=[^ ]+' | cut -d= -f2 | xargs)" # str
if [ -n "${MEV}" ]; then
  SERIES="${SERIES} @ ${MEV}"
fi

FILE_JS="/usr/syno/synoman/webman/modules/AdminCenter/admin_center.js"
FILE_GZ="${FILE_JS}.gz"

if [ ! -f "${FILE_JS}" ] && [ ! -f "${FILE_GZ}" ]; then
  echo "File ${FILE_JS} does not exist"
  exit 0
fi

if [ "${1}" = "-r" ]; then
  if [ -f "${FILE_GZ}.bak" ]; then
    rm -f "${FILE_JS}" "${FILE_GZ}"
    mv -f "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  elif [ -f "${FILE_JS}.bak" ]; then
    mv -f "${FILE_JS}.bak" "${FILE_JS}"
  fi
  systemctl stop cpuinfo.service cpuinfo-setup.service 2>/dev/null || kill -9 "$(ps aux 2>/dev/null | grep -F "/usr/sbin/cpuinfo" | grep -v grep | awk '{print $2}' | head -1)" 2>/dev/null || true
  [ -f "/etc/nginx/nginx.conf.bak" ] && mv -f /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && mv -f /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
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

applyPatch() {
  # $1=description $2=grep-anchor(BRE) $3=sed-script
  if grep -q "$2" "${FILE_JS}"; then
    sed -i "$3" "${FILE_JS}"
    return 0
  fi
  echo "cpuinfo: $1 anchor not found, skipping"
  return 1
}

CARDN=$(ls -d /sys/class/drm/card* 2>/dev/null | head -1)
if [ -d "${CARDN}" ]; then
  PCIDN="$(awk -F= '/PCI_SLOT_NAME/ {print $2}' "${CARDN}/device/uevent" 2>/dev/null)"
  LNAME="$(lspci -s ${PCIDN:-"99:99.9"} 2>/dev/null | sed "s/.*: //")"
  # LABLE="$(cat "/sys/class/drm/card0/device/label" 2>/dev/null)"
  CLOCK="0 MHz"
  [ -f "${CARDN}/gt_max_freq_mhz" ] && CLOCK="$(cat "${CARDN}/gt_max_freq_mhz" 2>/dev/null) MHz"
  [ -f "${CARDN}/device/pp_dpm_sclk" ] && CLOCK="$(cat "${CARDN}/device/pp_dpm_sclk" 2>/dev/null | grep '\*' | awk '{print $2}') MHz"
  MEMORY="$(awk '{s=(strtonum($2)-strtonum($1)+1)/1048576} (and(strtonum($3),0x200))&&(and(strtonum($3),0x2000))&&(and(strtonum($3),0x40000))&&s>0{print int(s) " MiB"; exit}' "${CARDN}/device/resource" 2>/dev/null)"
  if [ -n "${LNAME}" ] && [ -n "${CLOCK}" ] && [ -n "${MEMORY}" ]; then
    echo "GPU Info set to: \"${LNAME}\" \"${CLOCK}\" \"${MEMORY}\""
    if grep -q 'support_nvidia_gpu' "${FILE_JS}"; then
      # t.gpu={};t.gpu.clock=\"455 MHz\";t.gpu.memory=\"8192 MiB\";t.gpu.name=\"Tesla P4\";t.gpu.temperature_c=47;t.gpu.tempwarn=false;
      applyPatch "nvidia GPU info injection (getActiveApi)" 't=this\.getActiveApi(t);let' \
        "s/t=this.getActiveApi(t);let/t=this.getActiveApi(t);if(!t.gpu){t.gpu={};t.gpu.clock=\"${CLOCK}\";t.gpu.memory=\"${MEMORY}\";t.gpu.name=\"${LNAME}\";}let/g"
    else
      # b.gpu_info=[{name:\"Tesla P4\",status:\"compatible\",clock:\"455 MHz\",memory:\"8192 MiB\",pci_slot_num:\"0000:00:1c.0\",built_in_gpu_slot_num:\"\",temperature_c:47,tempwarn:false}];
      PCISLOT="${PCIDN:-}"
      applyPatch "legacy GPU info injection (getActiveApi)" 't=this\.getActiveApi(t);let' \
        "s/t=this.getActiveApi(t);let/t=this.getActiveApi(t);if(!b.support_gpu){b.support_gpu=true;b.gpu_info=[{name:\"${LNAME}\",status:\"compatible\",clock:\"${CLOCK}\",memory:\"${MEMORY}\",pci_slot_num:\"${PCISLOT}\",built_in_gpu_slot_num:\"\",temperature_c:0,tempwarn:false}];}let/g"
    fi
  fi
fi
if [ "${MEV}" = "physical" ]; then
  LEGACY_SYS_TEMP_PATCHED=0
  if grep -q 'support_nvidia_gpu' "${FILE_JS}"; then
    applyPatch "nvidia GPU support flag (_D(\"support_nvidia_gpu\")})" '_D("support_nvidia_gpu")},' \
      's/_D("support_nvidia_gpu")},/_D("support_nvidia_gpu")||true},/g'
    applyPatch "GPU temp renderer (,C,D);)" ',C,D);' \
      's/,C,D);/,C,t.gpu.temperature_c?D+" \| "+this.renderTempFromC(t.gpu.temperature_c):D);/g'
    applyPatch "legacy sys_temp renderer (,t,i,s)})" ',t,i,s)}' \
      's/,t,i,s)}/,t,i,e.sys_temp?s+" \| "+this.renderTempFromC(e.sys_temp):s)}/g' \
      && LEGACY_SYS_TEMP_PATCHED=1
    applyPatch "fan RPM renderer (rcpower,n)" '_T("rcpower",n),' \
      's/_T("rcpower",n),/_T("rcpower", n)?e.fan_list?_T("rcpower", n) + e.fan_list.map(fan => ` | ${fan} RPM`).join(""):_T("rcpower", n):e.fan_list?e.fan_list.map(fan => `${fan} RPM`).join(" | "):_T("rcpower", n),/g'
  else
    applyPatch "legacy sys_temp renderer (,t,i,n)})" ',t,i,n)}' \
      's/,t,i,n)}/,t,i,e.sys_temp?n+" \| "+this.renderTempFromC(e.sys_temp):n)}/g' \
      && LEGACY_SYS_TEMP_PATCHED=1
    applyPatch "legacy GPU temp renderer (font_normal)" 'font_normal"),"</div>","</div>"\].join("")' \
      's#font_normal"),"</div>","</div>"].join("")#font_normal")," | "+this.renderTempFromC(h),"</div>","</div>"].join("")#g'
    applyPatch "fan RPM renderer (rcpower,s)" '_T("rcpower",s),' \
      's/_T("rcpower",s),/_T("rcpower", s)?e.fan_list?_T("rcpower", s) + e.fan_list.map(fan => ` | ${fan} RPM`).join(""):_T("rcpower", s):e.fan_list?e.fan_list.map(fan => `${fan} RPM`).join(" | "):_T("rcpower", s),/g'
  fi

  if [ "${LEGACY_SYS_TEMP_PATCHED}" -eq 0 ]; then
    applyPatch "sys_temp row (rcfancontrol_desc)" 'i.unshift(\[_T("rcpower","rcfancontrol_desc")' \
      's/i\.unshift(\[_T("rcpower","rcfancontrol_desc"),/e.sys_temp\&\&i.unshift(["System Temperature",this.renderTempFromC(e.sys_temp),n]),i.unshift([_T("rcpower","rcfancontrol_desc"),/g'
  fi
fi

[ -f "${FILE_GZ}.bak" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"

[ ! -f "/etc/nginx/nginx.conf.bak" ] && cp -pf /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
sed -i 's|/run/synoscgi.sock;|/run/arc_synoscgi.sock;|g' /etc/nginx/nginx.conf
[ ! -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -pf /usr/syno/share/nginx/nginx.mustache /usr/syno/share/nginx/nginx.mustache.bak
sed -i 's|/run/synoscgi.sock;|/run/arc_synoscgi.sock;|g' /usr/syno/share/nginx/nginx.mustache

# Wait for the cpuinfo daemon to create the socket before reloading nginx.
TIMEOUT=10
while [ ! -S "/run/arc_synoscgi.sock" ] && [ "${TIMEOUT}" -gt 0 ]; do
  sleep 1
  TIMEOUT=$((TIMEOUT - 1))
done
if [ ! -S "/run/arc_synoscgi.sock" ]; then
  echo "cpuinfo: socket /run/arc_synoscgi.sock did not appear, reverting nginx patch"
  [ -f "/etc/nginx/nginx.conf.bak" ] && mv -f /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && mv -f /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  exit 1
fi

systemctl reload nginx

exit 0