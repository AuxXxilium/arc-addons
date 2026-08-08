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
  # Restore with cp, not mv: keeping the .bak means a later re-run still has a
  # pristine reference. A mv here leaves the system with no restore point at
  # all, and the next run then adopts the *current* (possibly patched) file as
  # its new "pristine" baseline, baking the patches in permanently.
  if [ -f "${FILE_GZ}.bak" ]; then
    rm -f "${FILE_JS}" "${FILE_GZ}"
    cp -pf "${FILE_GZ}.bak" "${FILE_GZ}"
    gzip -dc "${FILE_GZ}" >"${FILE_JS}"
  elif [ -f "${FILE_JS}.bak" ]; then
    cp -pf "${FILE_JS}.bak" "${FILE_JS}"
    # nginx has gzip_static on, so a stale .gz would be served in preference to
    # the .js we just restored. Keep the pair consistent.
    [ -f "${FILE_GZ}" ] && gzip -c "${FILE_JS}" >"${FILE_GZ}"
  else
    echo "cpuinfo: no backup found - admin_center.js is left as-is and may still be patched"
    echo "cpuinfo: reinstall AdminCenter if DSM's System Information page misbehaves"
  fi
  systemctl stop cpuinfo.service cpuinfo-setup.service 2>/dev/null || kill -9 "$(ps aux 2>/dev/null | grep -F "/usr/sbin/cpuinfo" | grep -v grep | awk '{print $2}' | head -1)" 2>/dev/null || true
  [ -f "/etc/nginx/nginx.conf.bak" ] && cp -pf /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -pf /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  systemctl reload nginx
  exit 0
fi

# Never adopt an already-patched file as the pristine baseline. Without this
# check a .gz regenerated from a patched .js (by us or by a DSM update landing
# mid-cycle) becomes the permanent "original", so every later run restores
# patched content and -r can never repair the system.
_is_patched() {
  [ -f "$1" ] || return 1
  grep -q 'renderTempFromC(e\.sys_temp)\|e\.fan_list\.map\|t\.gpu||(t\.gpu=' "$1" 2>/dev/null
}

if [ -f "${FILE_GZ}" ]; then
  if [ ! -f "${FILE_GZ}.bak" ]; then
    if gzip -dc "${FILE_GZ}" 2>/dev/null | grep -q 'renderTempFromC(e\.sys_temp)\|e\.fan_list\.map\|t\.gpu||(t\.gpu='; then
      echo "cpuinfo: ${FILE_GZ} is already patched and no pristine backup exists - refusing to"
      echo "cpuinfo: adopt it as the baseline. Reinstall AdminCenter to restore, then re-run."
      exit 1
    fi
    cp -pf "${FILE_GZ}" "${FILE_GZ}.bak"
  fi
else
  if [ ! -f "${FILE_JS}.bak" ]; then
    if _is_patched "${FILE_JS}"; then
      echo "cpuinfo: ${FILE_JS} is already patched and no pristine backup exists - refusing to"
      echo "cpuinfo: adopt it as the baseline. Reinstall AdminCenter to restore, then re-run."
      exit 1
    fi
    cp -pf "${FILE_JS}" "${FILE_JS}.bak"
  fi
fi

rm -f "${FILE_JS}" 2>/dev/null
if [ -f "${FILE_GZ}.bak" ]; then
  gzip -dc "${FILE_GZ}.bak" >"${FILE_JS}"
else
  cp -pf "${FILE_JS}.bak" "${FILE_JS}"
fi

applyPatch() {
  # $1=description $2=grep-anchor(BRE) $3=sed-script
  if grep -q "$2" "${FILE_JS}"; then
    sed -i "$3" "${FILE_JS}"
    return 0
  fi
  echo "cpuinfo: $1 anchor not found, skipping"
  return 1
}

# re-inserts the whole matched anchor text via sed's replacement metachar.
_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/&/\\&/g; s/#/\\#/g'; }

sed -i "s#\(\(,\)\|\((\)\).\.cpu_vendor#\1\"$(_json_escape "${VENDOR}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_family#\1\"$(_json_escape "${FAMILY}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_series#\1\"$(_json_escape "${SERIES}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_cores#\1\"$(_json_escape "${CORES}")\"#g" "${FILE_JS}"

# Args: $1=vid (4 hex, no 0x) $2=did
_gpu_name_fallback() {
  local vid="$1" did="$2" dev="" vendor=""
  case "${vid}:${did}" in
    8086:5902) dev="Kaby Lake-S GT1 [HD Graphics 610]" ;;
    8086:5912) dev="Kaby Lake-S GT2 [HD Graphics 630]" ;;
    8086:3e90|8086:3e93) dev="CoffeeLake-S GT1 [UHD Graphics 610]" ;;
    8086:3e91|8086:3e92|8086:3e98) dev="CoffeeLake-S GT2 [UHD Graphics 630]" ;;
    8086:9ba8) dev="CometLake-S GT1 [UHD Graphics 610]" ;;
    8086:9bc5|8086:9bc8) dev="CometLake-S GT2 [UHD Graphics 630]" ;;
    8086:4c8a) dev="RocketLake-S GT1 [UHD Graphics 750]" ;;
    8086:4c8b) dev="RocketLake-S GT1 [UHD Graphics 730]" ;;
    8086:4680|8086:4690) dev="Alder Lake-S GT1 [UHD Graphics 770]" ;;
    8086:4682|8086:4692) dev="Alder Lake-S GT1 [UHD Graphics 730]" ;;
    8086:4693) dev="Alder Lake-S GT1 [UHD Graphics 710]" ;;
    8086:46d0|8086:46d1|8086:46d2) dev="Alder Lake-N [UHD Graphics]" ;;
    8086:a780) dev="Raptor Lake-S GT1 [UHD Graphics 770]" ;;
    8086:a781|8086:a782|8086:a783|8086:a788|8086:a789|8086:a78a|8086:a78b) dev="Raptor Lake-S [UHD Graphics]" ;;
    1002:6985) dev="Lexa XT [Radeon PRO WX 3100]" ;;
  esac
  case "${vid}" in
    8086) vendor="Intel Corporation" ;;
    10de) vendor="NVIDIA Corporation" ;;
    1002) vendor="Advanced Micro Devices, Inc. [AMD/ATI]" ;;
  esac
  if [ -n "${dev}" ]; then
    printf '%s %s' "${vendor:-Vendor ${vid}}" "${dev}"
  elif [ -n "${vendor}" ]; then
    printf '%s Graphics [%s:%s]' "${vendor}" "${vid}" "${did}"
  else
    printf 'Device [%s:%s]' "${vid}" "${did}"
  fi
}

FIRST_NAME=""; FIRST_CLOCK=""; FIRST_MEMORY=""

# 1. DRM cards (Intel i915 / AMD amdgpu). NVIDIA is skipped here and handled
#    via nvidia-smi below, since its proprietary driver exposes no
#    /sys/class/drm/card* node unless nvidia-drm modeset=1.
for CARDN in /sys/class/drm/card[0-9]*; do
  [ -d "${CARDN}" ] || continue
  case "${CARDN##*/}" in *-*) continue ;; esac          # skip connector nodes (card0-DP-1)
  DRV="$(awk -F= '/^DRIVER=/{print $2}' "${CARDN}/device/uevent" 2>/dev/null)"
  case "${DRV}" in nvidia|nvidia-drm) continue ;; esac
  PCIDN="$(awk -F= '/PCI_SLOT_NAME/ {print $2}' "${CARDN}/device/uevent" 2>/dev/null)"
  LNAME="$(lspci -s ${PCIDN:-"99:99.9"} 2>/dev/null | sed "s/.*: //" | sed "s/ *(rev [0-9a-fA-F]*)//")"
  if [ -z "${LNAME}" ] || printf '%s' "${LNAME}" | grep -qiE '^Device '; then
    GVID="$(sed 's/^0x//' "${CARDN}/device/vendor" 2>/dev/null)"
    GDID="$(sed 's/^0x//' "${CARDN}/device/device" 2>/dev/null)"
    [ -n "${GVID}" ] && [ -n "${GDID}" ] && LNAME="$(_gpu_name_fallback "${GVID}" "${GDID}")"
  fi
  CLOCK="0 MHz"
  [ -f "${CARDN}/gt_max_freq_mhz" ] && CLOCK="$(cat "${CARDN}/gt_max_freq_mhz" 2>/dev/null) MHz"
  if [ -f "${CARDN}/device/pp_dpm_sclk" ]; then
    GMHZ="$(awk '{v=$2; gsub(/[^0-9]/,"",v); if(v+0>m)m=v+0} END{print m}' "${CARDN}/device/pp_dpm_sclk" 2>/dev/null)"
    [ -n "${GMHZ}" ] && [ "${GMHZ}" != "0" ] && CLOCK="${GMHZ} MHz"
  fi
  MEMORY="$(awk '{s=(strtonum($2)-strtonum($1)+1)/1048576} (and(strtonum($3),0x200))&&(and(strtonum($3),0x2000))&&(and(strtonum($3),0x40000))&&s>0{print int(s) " MiB"; exit}' "${CARDN}/device/resource" 2>/dev/null)"
  [ -n "${LNAME}" ] && [ -n "${CLOCK}" ] && [ -n "${MEMORY}" ] || continue
  [ -z "${FIRST_NAME}" ] && { FIRST_NAME="${LNAME}"; FIRST_CLOCK="${CLOCK}"; FIRST_MEMORY="${MEMORY}"; }
  echo "GPU Info set to: \"${LNAME}\" \"${CLOCK}\" \"${MEMORY}\"${PCIDN:+ [${PCIDN}]}"
done

# 2. NVIDIA via nvidia-smi (proprietary driver). One row per GPU:
#    name, max graphics clock (MHz), total memory (MiB), pci.bus_id.
if command -v nvidia-smi >/dev/null 2>&1 && ls /dev/nvidia[0-9]* >/dev/null 2>&1; then
  while IFS=, read -r NVN NVC NVM NVPCI; do
    NVN="$(printf '%s' "${NVN}" | sed 's/^ *//; s/ *$//')"
    NVC="$(printf '%s' "${NVC}" | tr -dc '0-9')"
    NVM="$(printf '%s' "${NVM}" | tr -dc '0-9')"
    # nvidia-smi pci.bus_id: "00000000:01:00.0" -> strip leading 4 zeros -> "0000:01:00.0"
    NVPCI="$(printf '%s' "${NVPCI}" | tr -d ' ' | cut -c5-)"
    [ -n "${NVN}" ] || continue
    NVNAME="NVIDIA ${NVN}"; NVCLOCK="${NVC:-0} MHz"; NVMEM="${NVM:-0} MiB"
    [ -z "${FIRST_NAME}" ] && { FIRST_NAME="${NVNAME}"; FIRST_CLOCK="${NVCLOCK}"; FIRST_MEMORY="${NVMEM}"; }
    echo "GPU Info (nvidia) set to: \"${NVNAME}\" \"${NVCLOCK}\" \"${NVMEM}\"${NVPCI:+ [${NVPCI}]}"
  done < <(nvidia-smi --query-gpu=name,clocks.max.graphics,memory.total,pci.bus_id --format=csv,noheader,nounits 2>/dev/null)
fi

if [ -n "${FIRST_NAME}" ]; then
  echo "GPU Info (legacy t.gpu) set to: \"${FIRST_NAME}\" \"${FIRST_CLOCK}\" \"${FIRST_MEMORY}\""
  applyPatch "GPU info injection (getActiveApi)" 't=this\.getActiveApi(t);let' \
    "s#t=this.getActiveApi(t);let#t=this.getActiveApi(t);t.gpu||(t.gpu={clock:\"${FIRST_CLOCK}\",memory:\"${FIRST_MEMORY}\",name:\"$(_json_escape "${FIRST_NAME}")\"});let#g"
fi

  LEGACY_SYS_TEMP_PATCHED=0
  if grep -q 'support_nvidia_gpu' "${FILE_JS}"; then
    applyPatch "nvidia GPU support flag (_D(\"support_nvidia_gpu\")})" '_D("support_nvidia_gpu")},' \
      's/_D("support_nvidia_gpu")},/_D("support_nvidia_gpu")||true},/g'
    applyPatch "GPU temp renderer (,C,D);)" ',C,D);' \
      's/,C,D);/,C,t.gpu.temperature_c?D+" \| "+this.renderTempFromC(t.gpu.temperature_c):D);/g'
  fi

  _CPUVAR="$(grep -oE ',t,i,[a-z]\)' "${FILE_JS}" | head -1 | sed 's/.*,//; s/)//')"
  if [ -n "${_CPUVAR}" ]; then
    applyPatch "sys_temp renderer (,t,i,${_CPUVAR})})" ",t,i,${_CPUVAR})}" \
      "s/,t,i,${_CPUVAR})}/,t,i,e.sys_temp?${_CPUVAR}+\" \\| \"+this.renderTempFromC(e.sys_temp):${_CPUVAR})}/g" \
      && LEGACY_SYS_TEMP_PATCHED=1
  else
    echo "cpuinfo: sys_temp — pattern ',t,i,X)' not found, skipping"
  fi

  applyPatch "PCIe slot vendor prefix (Synology \${r.cardName})" '`Synology ${r\.cardName}`' \
    's#`Synology ${r\.cardName}`#`${r.cardName}`#g'

  applyPatch "DSM 7.4 GPU section gate (b.support_gpu)" 'if(b\.support_gpu){' \
    's#if(b\.support_gpu){const \([a-z]\)=this\.formatGpuInfo(b\.gpu_info)#if(b.support_gpu||t.gpu_info){const \1=this.formatGpuInfo(b.support_gpu?b.gpu_info:t.gpu_info)#g'

  if ! grep -q 'support_nvidia_gpu' "${FILE_JS}"; then
    if grep -q 'u?_T("system","over_temperature"):_T("helpbrowser","font_normal"),"</div>","</div>"\].join' "${FILE_JS}"; then
      applyPatch "DSM 7.4 GPU temp renderer (formatGpuInfo)" \
        'u?_T("system","over_temperature"):_T("helpbrowser","font_normal"),"</div>","</div>"\].join' \
        's#u?_T("system","over_temperature"):_T("helpbrowser","font_normal"),"</div>","</div>"\].join#(u?_T("system","over_temperature"):_T("helpbrowser","font_normal"))+(h?" | "+this.renderTempFromC(h):""),"</div>","</div>"].join#g'
    else
      applyPatch "legacy GPU temp renderer (font_normal)" 'font_normal"),"</div>","</div>"\].join("")' \
        's#font_normal"),"</div>","</div>"].join("")#font_normal")," | "+this.renderTempFromC(h),"</div>","</div>"].join("")#g'
    fi
  fi

  _FANVAR="$(grep -oE '"rcpower",[a-z]\)' "${FILE_JS}" | head -1 | sed 's/.*,//; s/)//')"
  if [ -n "${_FANVAR}" ]; then
    FAN_SED="/tmp/_cpuinfo_fan_patch.sed"
    printf 's/_T("rcpower",%s),/_T("rcpower", %s)?e.fan_list?_T("rcpower", %s) + e.fan_list.map(fan => ` | ${fan} RPM`).join(""):_T("rcpower", %s):e.fan_list?e.fan_list.map(fan => `${fan} RPM`).join(" | "):_T("rcpower", %s),/g\n' \
      "${_FANVAR}" "${_FANVAR}" "${_FANVAR}" "${_FANVAR}" "${_FANVAR}" >"${FAN_SED}"
    if grep -q "\"rcpower\",${_FANVAR})," "${FILE_JS}"; then
      sed -i -f "${FAN_SED}" "${FILE_JS}"
      echo "cpuinfo: fan RPM renderer (rcpower,${_FANVAR}) applied"
    else
      echo "cpuinfo: fan RPM renderer (rcpower,${_FANVAR}) anchor not found, skipping"
    fi
    rm -f "${FAN_SED}"
  else
    echo "cpuinfo: fan_list — pattern '_T(\"rcpower\",X)' not found, skipping"
  fi

  if [ "${LEGACY_SYS_TEMP_PATCHED}" -eq 0 ]; then
    applyPatch "sys_temp row (rcfancontrol_desc)" 'i.unshift(\[_T("rcpower","rcfancontrol_desc")' \
      's/i\.unshift(\[_T("rcpower","rcfancontrol_desc"),/e.sys_temp\&\&i.unshift(["System Temperature",this.renderTempFromC(e.sys_temp),n]),i.unshift([_T("rcpower","rcfancontrol_desc"),/g'
  fi

# nginx runs with gzip_static on, so it serves admin_center.js.gz in preference
# to admin_center.js whenever the .gz exists. Regenerating it only when a
# .gz.bak happened to exist left the two out of sync: the browser kept getting
# a stale .gz (potentially months old, from before a DSM update) while the
# freshly patched .js was never served. Always rebuild the .gz when one is
# present, so what nginx serves matches what we just patched.
if [ -f "${FILE_GZ}" ] || [ -f "${FILE_GZ}.bak" ]; then
  gzip -c "${FILE_JS}" >"${FILE_GZ}"
fi

# The nginx redirect below is only safe once the daemon owns the socket, and
# the daemon is a separate unit that this script never started. `-r` stops it,
# so any later manual run would otherwise sit out the timeout below and revert,
# reporting a missing socket rather than the stopped service that caused it.
if [ ! -S "/run/arc_synoscgi.sock" ]; then
  if systemctl start cpuinfo.service 2>/dev/null; then
    echo "cpuinfo: started cpuinfo.service"
  elif [ -x /usr/sbin/cpuinfo ]; then
    echo "cpuinfo: systemctl unavailable, starting /usr/sbin/cpuinfo directly"
    /usr/sbin/cpuinfo &
  fi
fi

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
  echo "cpuinfo: the daemon is not running - check 'systemctl status cpuinfo.service'"
  echo "cpuinfo: or run /usr/sbin/cpuinfo in the foreground to see why it exits"
  # cp, not mv: keep the .bak so a later run still has a pristine reference.
  [ -f "/etc/nginx/nginx.conf.bak" ] && cp -pf /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
  [ -f "/usr/syno/share/nginx/nginx.mustache.bak" ] && cp -pf /usr/syno/share/nginx/nginx.mustache.bak /usr/syno/share/nginx/nginx.mustache
  exit 1
fi

systemctl reload nginx

exit 0