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

applyPatch() {
  # $1=description $2=grep-anchor(BRE) $3=sed-script
  if grep -q "$2" "${FILE_JS}"; then
    sed -i "$3" "${FILE_JS}"
    return 0
  fi
  echo "cpuinfo: $1 anchor not found, skipping"
  return 1
}

# _json_escape makes a string safe both as JSON string content and as a sed
# replacement/delimiter operand (values from this are inserted into sed
# replacement text using '#' as the delimiter in several call sites below,
# and hardware/vendor strings from lspci or /proc/cpuinfo can contain '#',
# '&', or '/' — any one of which, left unescaped, either breaks the sed
# command (silently truncating the JS patch mid-statement) or, for '&',
# re-inserts the whole matched anchor text via sed's replacement metachar.
_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/&/\\&/g; s/#/\\#/g'; }

sed -i "s#\(\(,\)\|\((\)\).\.cpu_vendor#\1\"$(_json_escape "${VENDOR}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_family#\1\"$(_json_escape "${FAMILY}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_series#\1\"$(_json_escape "${SERIES}")\"#g" "${FILE_JS}"
sed -i "s#\(\(,\)\|\((\)\).\.cpu_cores#\1\"$(_json_escape "${CORES}")\"#g" "${FILE_JS}"

# _gpu_name_fallback resolves a GPU display name from PCI vendor:device IDs
# when lspci's pci.ids database is missing/outdated and only prints the raw
# "Device <vid>:<did>". Newer (2021+) Intel desktop iGPUs (Alder/Raptor Lake)
# are the common victims. A curated table gives exact marketing names; anything
# else falls back to a vendor-prefixed label so the result is never wrong.
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

# _pci_name resolves a PCI device display name from vendor:device IDs, mirroring
# _gpu_name_fallback. lspci is tried first; when pci.ids is missing/outdated it
# only yields "Device <ids>" (or nothing), so a curated table + vendor label is
# used, always suffixed with "[vid:did]". Args: $1=vid $2=did (4 hex, no 0x)
_pci_name() {
  local vid="$1" did="$2" dev="" vendor="" name=""
  name="$(lspci -d "${vid}:${did}" 2>/dev/null | head -1 | sed 's/^[0-9a-f:.]* [^:]*: //; s/ *(rev [0-9a-fA-F]*)//')"
  if [ -n "${name}" ] && ! printf '%s' "${name}" | grep -qiE '^Device '; then
    printf '%s [%s:%s]' "${name}" "${vid}" "${did}"; return
  fi
  case "${vid}:${did}" in
    10ec:8168|10ec:8161|10ec:8169) dev="RTL8111/8168/8411 Gigabit Ethernet" ;;
    10ec:8125) dev="RTL8125 2.5GbE" ;;
    10ec:8126) dev="RTL8126 5GbE" ;;
    8086:1533) dev="I210 Gigabit Network" ;;
    8086:1539) dev="I211 Gigabit Network" ;;
    8086:1521) dev="I350 Gigabit Network" ;;
    8086:10d3) dev="82574L Gigabit Network" ;;
    8086:1572|8086:1583|8086:1584|8086:1585) dev="X710/XL710 10/40GbE" ;;
    8086:1563|8086:15d1) dev="X550 10GbE" ;;
    15b3:1015|15b3:1017) dev="ConnectX-4/5 25/100GbE" ;;
  esac
  case "${vid}" in
    8086) vendor="Intel" ;;
    10ec) vendor="Realtek" ;;
    10de) vendor="NVIDIA" ;;
    1002) vendor="AMD/ATI" ;;
    1b21|1b4b) vendor="ASMedia/Marvell" ;;
    1000) vendor="Broadcom/LSI" ;;
    9005) vendor="Adaptec" ;;
    15b3) vendor="Mellanox" ;;
    1c5c|144d|1cc1|1e0f|c0a9) vendor="NVMe SSD" ;;
  esac
  if [ -n "${dev}" ]; then
    printf '%s %s [%s:%s]' "${vendor:-Vendor ${vid}}" "${dev}" "${vid}" "${did}"
  elif [ -n "${vendor}" ]; then
    printf '%s Device [%s:%s]' "${vendor}" "${vid}" "${did}"
  else
    printf 'Device [%s:%s]' "${vid}" "${did}"
  fi
}

# _pci_slot_info prints the external_pci_slot_info JSON array. An "add-in PCIe
# card" is any endpoint function 0 that sits behind a root-port bridge (bus !=
# 00) and is not itself a bridge. Slots are numbered 1..N in PCI address order.
# Prints "[]" when none are found.
_pci_slot_info() {
  local D bdf bus cls vid did nm elems="" slot=0 e
  for D in $(ls -d /sys/bus/pci/devices/0000:* 2>/dev/null | sort); do
    bdf="$(basename "${D}")"
    bus="$(echo "${bdf}" | cut -d: -f2)"
    [ "${bus}" = "00" ] && continue                 # onboard/root complex — skip
    cls="$(cat "${D}/class" 2>/dev/null)"
    case "${cls}" in 0x0604*|0x0600*|0x0601*) continue ;; esac  # bridges — skip
    [ "${bdf##*.}" = "0" ] || continue              # multifunction: function 0 only
    vid="$(sed 's/^0x//' "${D}/vendor" 2>/dev/null)"
    did="$(sed 's/^0x//' "${D}/device" 2>/dev/null)"
    [ -n "${vid}" ] && [ -n "${did}" ] || continue
    nm="$(_pci_name "${vid}" "${did}")"
    slot=$((slot + 1))
    e="$(printf '{"slot":"%s","Occupied":"yes","Recognized":"yes","cardName":"%s"}' \
      "${slot}" "$(_json_escape "${nm}")")"
    [ -z "${elems}" ] && elems="${e}" || elems="${elems},${e}"
  done
  printf '[%s]' "${elems}"
}

# Accumulate one JSON object per GPU into GPU_ELEMS (comma-joined). FIRST_*
# captures the first GPU for the legacy DSM <= 7.3 single-object t.gpu path.
GPU_ELEMS=""
FIRST_NAME=""; FIRST_CLOCK=""; FIRST_MEMORY=""
_append_gpu() { [ -z "${GPU_ELEMS}" ] && GPU_ELEMS="$1" || GPU_ELEMS="${GPU_ELEMS},$1"; }

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
  # built_in_gpu_slot_num keeps the iGPU labeled as the onboard GPU slot;
  # discrete cards use pci_slot_num so Info Center shows a PCIe slot row.
  if [ "${DRV}" = "i915" ] || [ -z "${PCIDN}" ]; then
    _append_gpu "$(printf '{"name":"%s","status":"compatible","clock":"%s","memory":"%s","pci_slot_num":"","built_in_gpu_slot_num":"1","temperature_c":0,"tempwarn":false}' \
      "$(_json_escape "${LNAME}")" "${CLOCK}" "${MEMORY}")"
  else
    _append_gpu "$(printf '{"name":"%s","status":"compatible","clock":"%s","memory":"%s","pci_slot_num":"%s","built_in_gpu_slot_num":"","temperature_c":0,"tempwarn":false}' \
      "$(_json_escape "${LNAME}")" "${CLOCK}" "${MEMORY}" "${PCIDN}")"
  fi
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
    _append_gpu "$(printf '{"name":"%s","status":"compatible","clock":"%s","memory":"%s","pci_slot_num":"%s","built_in_gpu_slot_num":"","temperature_c":0,"tempwarn":false}' \
      "$(_json_escape "${NVNAME}")" "${NVCLOCK}" "${NVMEM}" "${NVPCI:-}")"
  done < <(nvidia-smi --query-gpu=name,clocks.max.graphics,memory.total,pci.bus_id --format=csv,noheader,nounits 2>/dev/null)
fi

# PCIe add-in slot occupancy — external_pci_slot_info. Baked in only when at
# least one add-in card is present; DSM's genuine (all-"no") value is left
# alone otherwise. cardName's default "Synology " prefix is dropped below so
# the Info Center shows the bare device name.
PCISLOTS="$(_pci_slot_info)"

if [ -n "${GPU_ELEMS}" ] || { [ -n "${PCISLOTS}" ] && [ "${PCISLOTS}" != "[]" ]; }; then
  if grep -q 'support_nvidia_gpu' "${FILE_JS}"; then
    # Legacy DSM <= 7.3 client path only understands a single t.gpu object;
    # only the first detected GPU is exposed here.
    if [ -n "${FIRST_NAME}" ]; then
      echo "GPU Info (legacy t.gpu) set to: \"${FIRST_NAME}\" \"${FIRST_CLOCK}\" \"${FIRST_MEMORY}\""
      # '#' delimiter: GPU/device names may contain '/' (e.g. lspci's
      # "GeForce RTX 4090/PCIe/SSE2"), which would otherwise break the s/// syntax.
      applyPatch "nvidia GPU info injection (getActiveApi)" 't=this\.getActiveApi(t);let' \
        "s#t=this.getActiveApi(t);let#t=this.getActiveApi(t);if(!t.gpu){t.gpu={};t.gpu.clock=\"${FIRST_CLOCK}\";t.gpu.memory=\"${FIRST_MEMORY}\";t.gpu.name=\"$(_json_escape "${FIRST_NAME}")\";}let#g"
    fi
  else
    # DSM 7.4 path: full multi-GPU array + PCIe slot occupancy.
    PATCH=""
    if [ -n "${GPU_ELEMS}" ]; then
      PATCH="if(!b.support_gpu){b.support_gpu=true;b.gpu_info=[${GPU_ELEMS}];}"
    fi
    if [ -n "${PCISLOTS}" ] && [ "${PCISLOTS}" != "[]" ]; then
      echo "PCIe slot info set to: ${PCISLOTS}"
      PATCH="${PATCH}if(!b.external_pci_slot_info||!b.external_pci_slot_info.length){b.external_pci_slot_info=${PCISLOTS};}"
    fi
    if [ -n "${PATCH}" ]; then
      # '#' delimiter: GPU/device names embedded in PATCH may contain '/'
      # (e.g. lspci's "GeForce RTX 4090/PCIe/SSE2"), which would otherwise
      # break the s/// syntax.
      applyPatch "DSM 7.4 GPU/PCIe info injection (getActiveApi)" 't=this\.getActiveApi(t);let' \
        "s#t=this.getActiveApi(t);let#t=this.getActiveApi(t);${PATCH}let#g"
    fi
  fi
fi

# PCIe slot device name: formatExternalDeviceInfo() renders an occupied slot
# as "Synology ${r.cardName}"; drop the hardcoded prefix so our injected
# cardName (the real device name) shows bare.
if grep -qF '`Synology ${r.cardName}`' "${FILE_JS}"; then
  sed -i 's#`Synology ${r.cardName}`#`${r.cardName}`#g' "${FILE_JS}"
  echo "pcie_slot cardName prefix patch applied (drop 'Synology ')"
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
    # DSM 7.4's formatGpuInfo() renders each gpu_info[] entry's thermal status
    # as normal/over_temperature with no temperature suffix.
    # Try the precise anchor (ternary + ,"</div>","</div>"].join) first; DSM
    # builds shuffle minified var names ('u'/'h' here) but not this structure.
    # Falls back to the older, looser anchor if DSM's minifier reshapes it.
    if grep -q 'over_temperature"):_T("helpbrowser","font_normal"),"</div>","</div>"\].join' "${FILE_JS}"; then
      applyPatch "DSM 7.4 GPU temp renderer (formatGpuInfo)" \
        'over_temperature"):_T("helpbrowser","font_normal"),"</div>","</div>"\].join' \
        's#\(_T("system","over_temperature"):_T("helpbrowser","font_normal")\),"</div>","</div>"\].join#(\1)+(h?" | "+this.renderTempFromC(h):""),"</div>","</div>"].join#g'
    else
      applyPatch "legacy GPU temp renderer (font_normal)" 'font_normal"),"</div>","</div>"\].join("")' \
        's#font_normal"),"</div>","</div>"].join("")#font_normal")," | "+this.renderTempFromC(h),"</div>","</div>"].join("")#g'
    fi
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