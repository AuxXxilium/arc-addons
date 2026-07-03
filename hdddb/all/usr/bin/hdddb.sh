#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Patches DSM disk compatibility databases so that any installed drive is
# recognised as supported.
#
# Flags:
#   -n | --noupdate      Prevent DSM updating the drive databases
#   -r | --ram           Disable memory-compatibility checking
#   -w | --wdda          Disable WD Device Analytics warnings
#   -I | --ihm           Enable / update IronWolf Health Management
#   -e | --email         No-op (kept for call-site compatibility)
#   -S | --ssd           Set write_mostly on HDDs when internal SSDs are present
#   -p | --pcie          Enable M.2 add-on card pool support (support_m2_pool + UI patch)
#   -d | --dedup         Enable Btrfs deduplication for non-Synology drives (patches libhwcontrol)
#

# ── bootstrap ────────────────────────────────────────────────────────────────

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

# ── option parsing ────────────────────────────────────────────────────────────

noupdate=no
ram=no
wdda=no
ihm=no
ssd=no
pcie=no
dedup=no

for arg in "$@"; do
  case "$arg" in
    -n|--noupdate|--nodbupdate) noupdate=yes ;;
    -r|--ram)   ram=yes ;;
    -w|--wdda)  wdda=yes ;;
    -I|--ihm)   ihm=yes ;;
    -S|--ssd)   ssd=yes ;;
    -e|--email) ;;
    -p|--pcie)  pcie=yes ;;
    -d|--dedup) dedup=yes ;;
    *) ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────

SYNOINFO=/etc.defaults/synoinfo.conf

_get() { "$GKV" "$SYNOINFO" "$1"; }
_set() { "$SKV" "$SYNOINFO" "$1" "$2"; "$SKV" /etc/synoinfo.conf "$1" "$2"; }
_log() { echo "hdddb: $*"; }

# ── drive size ────────────────────────────────────────────────────────────────

disk_size_gb() {
  SECTORS="$(tr -d '\r\n' <"/sys/block/${1}/size" 2>/dev/null)"
  case "${SECTORS}" in
    *[!0-9]* | "") echo 0 ;;
    *) awk -v sectors="${SECTORS}" 'BEGIN { printf "%d\n", (sectors * 512 / 1000 / 1000 / 1000) + 0.5 }' ;;
  esac
}

# ── drive enumeration ─────────────────────────────────────────────────────────

collect_disks() {
  TMP="${1}"
  : >"${TMP}"

  for DISK_DIR in /run/synostorage/disks/*; do
    [ -d "${DISK_DIR}" ] || continue
    DEV="$(basename "${DISK_DIR}")"
    MODEL="$([ -f "${DISK_DIR}/model" ] && tr -d '\r\n' <"${DISK_DIR}/model" 2>/dev/null)"
    [ -n "${MODEL}" ] || MODEL="$([ -f "${DISK_DIR}/real_model" ] && tr -d '\r\n' <"${DISK_DIR}/real_model" 2>/dev/null)"
    [ -n "${MODEL}" ] || continue
    FIRM="$([ -f "${DISK_DIR}/firm" ] && tr -d '\r\n' <"${DISK_DIR}/firm" 2>/dev/null)"
    SIZE="$(disk_size_gb "${DEV}")"
    _log "  found (synostorage): ${DEV} model=${MODEL} firm=${FIRM} size=${SIZE}"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done

  for BLOCK_DIR in /sys/block/*; do
    [ -d "${BLOCK_DIR}" ] || continue
    DEV="$(basename "${BLOCK_DIR}")"
    case "${DEV}" in
      sata* | sd* | nvme*) ;;
      *) continue ;;
    esac
    grep -q "^${DEV}	" "${TMP}" 2>/dev/null && continue
    MODEL="$([ -f "${BLOCK_DIR}/device/model" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/model" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${MODEL}" ] || continue
    FIRM="$([ -f "${BLOCK_DIR}/device/firmware_rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/firmware_rev" 2>/dev/null)"
    [ -n "${FIRM}" ] || FIRM="$([ -f "${BLOCK_DIR}/device/rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/rev" 2>/dev/null)"
    FIRM="$(printf '%s' "${FIRM}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    SIZE="$(disk_size_gb "${DEV}")"
    _log "  found (sysblock): ${DEV} model=${MODEL} firm=${FIRM} size=${SIZE}"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done

}

# ── database patching ─────────────────────────────────────────────────────────

patch_database() {
  local DB="${1}"
  local DISKS="${2}"
  local SUPPORT_INTERVAL='{"compatibility":"support","not_yet_rolling_status":"support","fw_dsm_update_status_notify":false,"barebone_installable":true,"barebone_installable_v2":"auto","smart_test_ignore":true,"smart_attr_ignore":true}'
  local DEV MODEL FIRM SIZE TMP
  jq -e '.disk_compatbility_info | type == "object"' "${DB}" >/dev/null 2>&1 || return 0

  TMP="${DB}.tmp.$$"
  cp -p "${DB}" "${TMP}" || return 0
  while IFS="$(printf '\t')" read -r DEV MODEL FIRM SIZE; do
    [ -n "${MODEL}" ] || continue
    case "${SIZE}" in *[!0-9]* | "") SIZE=0 ;; esac
    jq -c \
      --arg model "${MODEL}" \
      --arg firm "${FIRM}" \
      --argjson size "${SIZE}" \
      --argjson interval "${SUPPORT_INTERVAL}" \
      '
      .disk_compatbility_info[$model] //= {}
      | .disk_compatbility_info[$model].default //= {}
      | if $size > 0 then .disk_compatbility_info[$model].default.size_gb = $size else . end
      | .disk_compatbility_info[$model].default.compatibility_interval = [$interval]
      | if $firm != "" then
          .disk_compatbility_info[$model][$firm] //= {}
          | .disk_compatbility_info[$model][$firm].fw_buildnumber //= 1
          | .disk_compatbility_info[$model][$firm].firm_bin //= ($firm + ".bin")
          | .disk_compatbility_info[$model][$firm].compatibility_interval = [$interval]
        else . end
      ' "${TMP}" >"${TMP}.new" && mv -f "${TMP}.new" "${TMP}" || {
      rm -f "${TMP}" "${TMP}.new"
      return 0
    }
  done <"${DISKS}"

  # Replace any remaining not_support/unverified values with support (catches fields jq didn't touch)
  sed -i 's/"not_support"/"support"/g; s/"unverified"/"support"/g' "${TMP}"

  chmod 644 "${TMP}" 2>/dev/null || true
  mv -f "${TMP}" "${DB}"
}

patch_storage_settings() {
  local DB="/var/lib/storage_setting/general_settings.db"
  local TMP
  [ -f "${DB}" ] || return 0
  jq -e . "${DB}" >/dev/null 2>&1 || return 0

  TMP="${DB}.tmp.$$"
  jq -c '.settings.allow_new_hcl_as_normal = {"dsm_ver":[],"values":[true]}' "${DB}" >"${TMP}" && mv -f "${TMP}" "${DB}"
}

patch_storagemanager_ui() {
  local strgmgr
  # DSM 7.2.1+ path, then older path
  for _p in \
    "/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js" \
    "/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"; do
    [ -f "${_p}" ] && strgmgr="${_p}" && break
  done
  [ -n "${strgmgr}" ] || return 0

  local changed=0
  # Remove "not a Synology disk" warning conditions from the UI
  if grep -q 'disk_reason_not_support' "${strgmgr}" 2>/dev/null; then
    sed -i 's/[^,]*disk_reason_not_support[^,]*,//g' "${strgmgr}" && changed=1
  fi
  if grep -q 'warnNonSynologyDisk\|isNotSynologyDisk\|not_syno_disk' "${strgmgr}" 2>/dev/null; then
    sed -i 's/[^,]*\(warnNonSynologyDisk\|isNotSynologyDisk\|not_syno_disk\)[^,]*,//g' "${strgmgr}" && changed=1
  fi
  # Remove M.2 add-on card not-supported warning
  if grep -q 'notSupportM2Pool_addOnCard' "${strgmgr}" 2>/dev/null; then
    sed -i 's/notSupportM2Pool_addOnCard:this.T("disk_info","disk_reason_m2_add_on_card"),//g' "${strgmgr}"
    sed -i 's/},{isConditionInvalid:0<this.pciSlot,invalidReason:"notSupportM2Pool_addOnCard"//g' "${strgmgr}"
    changed=1
  fi
  # Remove dedup-only-on-Synology-SSD warning (notSupportDedup / notSupportBtrfsDedup variants)
  if grep -qE 'notSupportDedup|notSupportBtrfsDedup' "${strgmgr}" 2>/dev/null; then
    sed -i 's/[^,]*notSupportDedup[^,]*,//g' "${strgmgr}"
    sed -i 's/[^,]*notSupportBtrfsDedup[^,]*,//g' "${strgmgr}"
    changed=1
  fi
  # Remove SHA (Synology HDD/SSD Array) restriction warnings
  if grep -qE 'notSupportM2Pool_SHA|notSupportM2Pool_3rdParty|notSupportM2Pool_blockList' "${strgmgr}" 2>/dev/null; then
    sed -i 's/[^,]*notSupportM2Pool_SHA[^,]*,//g' "${strgmgr}"
    sed -i 's/[^,]*notSupportM2Pool_3rdParty[^,]*,//g' "${strgmgr}"
    sed -i 's/[^,]*notSupportM2Pool_blockList[^,]*,//g' "${strgmgr}"
    changed=1
  fi
  [ "${changed}" -eq 1 ] && _log "StorageManager UI patched to suppress non-Synology disk warnings"
}

clear_pool_compatibility() {
  local FILE TMP
  for FILE in /run/space/pool_compatibility /run/space/pool_compatibility_legacy /var/lib/space/pool_compatibility /var/lib/space/pool_compatibility_legacy; do
    [ -f "${FILE}" ] || continue
    TMP="${FILE}.tmp.$$"
    awk -F= '
      {
        value = (NF > 1 ? $2 : $0)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        if (value == "at_risk" || value == "at_risk_high" || value == "not_support" || value == "unsupported" || value == "critical") next
        print
      }
    ' "${FILE}" >"${TMP}" && mv -f "${TMP}" "${FILE}"
  done
}

refresh_runtime() {
  local DISKS="${1}"
  local DEV MODEL FIRM SIZE DISK_DIR
  local SUPPORT_ACTION='{"allow_auto_repair":true,"allow_binding":true,"allow_detected_scan":true,"allow_ma_create":true,"cache_rescue_selectable":"yes","cache_selectable":"yes","cache_status":"healthy","disk_status":"support","hide_alloc_status":false,"hide_fw_version":false,"hide_is4Kn":false,"hide_remain_life":false,"hide_sb_days_left":false,"hide_serial":false,"hide_temperature":false,"hide_unc":false,"legacy_cache_rescue_selectable":"yes","legacy_cache_selectable":"yes","legacy_cache_status":"healthy","notification":false,"notify_health_status":true,"notify_lifetime":true,"notify_unc":true,"pool_rescue_selectable":"yes","pool_selectable":"yes","pool_status":"healthy","send_health_report":true,"show_lifetime_chart":true}'
  while IFS="$(printf '\t')" read -r DEV MODEL FIRM SIZE; do
    DISK_DIR="/run/synostorage/disks/${DEV}"
    [ -d "${DISK_DIR}" ] || continue
    printf 'support\n' >"${DISK_DIR}/compatibility" 2>/dev/null || true
    printf 'support\n' >"${DISK_DIR}/force_compatibility" 2>/dev/null || true
    printf '1\n' >"${DISK_DIR}/smart_attr_ignore" 2>/dev/null || true
    printf '1\n' >"${DISK_DIR}/smart_test_ignore" 2>/dev/null || true
    printf '%s' "${SUPPORT_ACTION}" >"${DISK_DIR}/compatibility_action" 2>/dev/null || true
    rm -f "${DISK_DIR}/compatibility.lock" "${DISK_DIR}/compatibility_action.lock" 2>/dev/null || true
  done <"${DISKS}"
}

# ── m2_pool_support ───────────────────────────────────────────────────────────

set_m2_pool_support() {
  for d in /run/synostorage/disks/nvme*/m2_pool_support; do
    [ -f "$d" ] && printf '1' >"$d"
  done
}

# ── synoinfo.conf patches ─────────────────────────────────────────────────────

_disable_dbupdates() {
  local dsmmajor dsmminor
  dsmmajor="$("$GKV" /etc.defaults/VERSION majorversion)"
  dsmminor="$("$GKV" /etc.defaults/VERSION minorversion)"

  if [ "${dsmmajor}${dsmminor}" -lt 73 ] 2>/dev/null; then
    local cur
    cur="$(_get drive_db_test_url)"
    if [ "$cur" != "127.0.0.1" ]; then
      _set drive_db_test_url "127.0.0.1"
      _log "drive DB auto-updates disabled (drive_db_test_url)"
    fi
  else
    local sopinfo
    for p in SynoOnlinePack_v3 SynoOnlinePack_v2 SynoOnlinePack; do
      [ -f "/var/packages/$p/INFO" ] && sopinfo="/var/packages/$p/INFO" && break
    done
    if [ -n "$sopinfo" ]; then
      local ver
      ver="$("$GKV" "$sopinfo" version)"
      if [ "${ver:0:4}" != "9999" ]; then
        "$SKV" "$sopinfo" version "9999${ver}"
        _log "drive DB auto-updates disabled (SynoOnlinePack version bumped)"
      fi
    fi
  fi
}

# ── PCIe / M.2 adaptor card support ──────────────────────────────────────────

_enable_pcie() {
  local cur
  cur="$(_get support_m2_pool)"
  if [ "${cur}" != "yes" ]; then
    _set support_m2_pool "yes"
    _log "pcie: support_m2_pool enabled"
  fi

  # Remove M.2 add-on card pool restriction from StorageManager UI
  local strgmgr
  for _p in \
    "/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js" \
    "/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"; do
    [ -f "${_p}" ] && strgmgr="${_p}" && break
  done
  if [ -n "${strgmgr}" ] && grep -q 'notSupportM2Pool_addOnCard' "${strgmgr}" 2>/dev/null; then
    sed -i 's/notSupportM2Pool_addOnCard:this.T("disk_info","disk_reason_m2_add_on_card"),//g' "${strgmgr}"
    sed -i 's/},{isConditionInvalid:0<this.pciSlot,invalidReason:"notSupportM2Pool_addOnCard"//g' "${strgmgr}"
    _log "pcie: StorageManager UI patched to allow M.2 add-on card pools"
  fi
}

# ── Deduplication ────────────────────────────────────────────────────────────

_enable_dedup() {
  local libhw="/usr/lib/libhwcontrol.so.1"
  local synoinfo2="/etc/synoinfo.conf"

  # Determine tiny dedupe eligibility (needs 16 GB; tiny needs only 4 GB)
  local ramtotal_mb=0
  while IFS= read -r line; do
    case "$line" in
      *"Size:"*[0-9]*MB*) ramtotal_mb=$((ramtotal_mb + ${line//[^0-9]/})) ;;
      *"Size:"*[0-9]*GB*) ramtotal_mb=$((ramtotal_mb + ${line//[^0-9]/} * 1024)) ;;
    esac
  done < <(dmidecode -t memory 2>/dev/null | grep -i "Size:")

  if [ "$ramtotal_mb" -ge 16384 ]; then
    _set support_btrfs_dedupe "yes"
    _set support_tiny_btrfs_dedupe "no"
    _log "dedup: full Btrfs deduplication enabled (${ramtotal_mb}MB RAM)"
  elif [ "$ramtotal_mb" -ge 4096 ]; then
    _set support_btrfs_dedupe "no"
    _set support_tiny_btrfs_dedupe "yes"
    _log "dedup: tiny Btrfs deduplication enabled (${ramtotal_mb}MB RAM)"
  else
    _log "dedup: insufficient RAM (${ramtotal_mb}MB), skipping"
    return
  fi

  # Patch libhwcontrol.so.1 to allow non-Synology drives to use dedupe
  [ -f "$libhw" ] || { _log "dedup: $libhw not found, skipping binary patch"; return; }

  local hexstring match poshex posrep bytes
  # Check if already patched (90 90 = NOP NOP)
  hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
  match=$(od -v -t x1 "$libhw" | sed 's/[^ ]* *//' | tr '\012' ' ' | grep -b -i -o "$hexstring" | cut -d: -f1 | head -1)
  if [ -n "$match" ]; then
    _log "dedup: libhwcontrol already patched"
    return
  fi

  # Find the original bytes to patch
  hexstring="80 3E 00 B8 01 00 00 00 75 2. 48 8B"
  match=$(od -v -t x1 "$libhw" | sed 's/[^ ]* *//' | tr '\012' ' ' | grep -b -i -o "$hexstring" | cut -d: -f1 | head -1)
  if [ -z "$match" ]; then
    _log "dedup: libhwcontrol patch target not found (DSM version mismatch?)"
    return
  fi

  local seek
  seek=$(( match / 3 ))
  poshex=$(printf "%x" "$seek")
  posrep=$(printf "%x" $((seek + 8)))

  # Backup before patching
  if [ ! -f "${libhw}.bak" ]; then
    cp -p "$libhw" "${libhw}.bak" && _log "dedup: backed up $libhw"
  fi

  if printf '%s' "${posrep}: 9090" | xxd -r - "$libhw"; then
    _log "dedup: libhwcontrol patched to allow non-Synology drive deduplication"
  else
    _log "dedup: failed to patch libhwcontrol"
  fi

  # Enable HDD dedupe config button in StorageManager UI
  local strgmgr
  for _p in \
    "/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js" \
    "/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"; do
    [ -f "${_p}" ] && strgmgr="${_p}" && break
  done
  if [ -n "$strgmgr" ] && grep -q '&&e.dedup_info.show_config_btn' "$strgmgr" 2>/dev/null; then
    sed -i 's/&&e.dedup_info.show_config_btn//g' "$strgmgr"
    _log "dedup: StorageManager UI patched to enable HDD dedupe config button"
  fi
}

# ── IronWolf Health Management ────────────────────────────────────────────────

_enable_ihm() {
  val="$(_get support_ihm)"
  [ "$val" != "yes" ] && _set support_ihm "yes" && _log "support_ihm enabled"

  if [ ! -f /usr/syno/sbin/dhm_tool ]; then
    _log "dhm_tool not found, IronWolf Health Management unavailable"
  else
    cur_ver="$(/usr/syno/sbin/dhm_tool --version 2>/dev/null | grep 'Utility Version' | awk '{print $NF}')"
    _log "dhm_tool version: $cur_ver"
  fi
}

# ── SSD write_mostly ─────────────────────────────────────────────────────────

# Set md0/md1 state for a drive's system+swap partitions
# $1: writemostly | in_sync   $2: device basename (sata1, sda, …)
_set_writemostly() {
  local state="$1" dev="$2"
  case "$dev" in
    sd*)
      # sdX: partitions are sdX1, sdX2
      printf '%s' "$state" >"/sys/block/md0/md/dev-${dev}1/state" 2>/dev/null && \
        _log "  ${dev} DSM partition: $state"
      printf '%s' "$state" >"/sys/block/md1/md/dev-${dev}2/state" 2>/dev/null && \
        _log "  ${dev} swap partition: $state"
      ;;
    *)
      # sataX / sasX: partitions are sataXp1, sataXp2
      printf '%s' "$state" >"/sys/block/md0/md/dev-${dev}p1/state" 2>/dev/null && \
        _log "  ${dev} DSM partition: $state"
      printf '%s' "$state" >"/sys/block/md1/md/dev-${dev}p2/state" 2>/dev/null && \
        _log "  ${dev} swap partition: $state"
      ;;
  esac
}

_apply_ssd_writemostly() {
  local -a internal_drives internal_hdds
  local internal_ssd_qty=0

  mapfile -t internal_drives < <(synodisk --enum -t internal 2>/dev/null | grep 'Disk path' | cut -d'/' -f3)
  [ "${#internal_drives[@]}" -eq 0 ] && { _log "ssd: no internal drives found"; return; }

  for drv in "${internal_drives[@]}"; do
    # synodisk --isssd: exit 0 = not SSD, exit 1 = is SSD
    if synodisk --isssd "/dev/${drv}" >/dev/null 2>&1; then
      internal_hdds+=("$drv")
    else
      internal_ssd_qty=$((internal_ssd_qty + 1))
    fi
  done

  if [ "$internal_ssd_qty" -gt 0 ] && [ "${#internal_hdds[@]}" -gt 0 ]; then
    _log "ssd: setting ${#internal_hdds[@]} HDD(s) to write_mostly (${internal_ssd_qty} SSD(s) present)"
    for drv in "${internal_hdds[@]}"; do
      _set_writemostly writemostly "$drv"
    done
  else
    _log "ssd: no mixed SSD+HDD setup detected, skipping write_mostly"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do
  "$SKV" "${F}" "support_disk_compatibility" "yes"
  "$SKV" "${F}" "forbid_unsupport_extdev" "no"
  "$SKV" "${F}" "support_btrfs_dedupe" "yes"
done

DISKS="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0

# synostoraged populates /run/synostorage/disks/ asynchronously.
# Wait up to 60s for at least one disk dir with a model file to appear.
_WAIT=0
while true; do
  _READY=0
  for _D in /run/synostorage/disks/*/model; do
    [ -f "${_D}" ] && { _READY=1; break; }
  done
  [ "${_READY}" -eq 1 ] && break
  if [ "${_WAIT}" -ge 60 ]; then
    _log "synostorage not ready after 60s, using /sys/block fallback..."
    break
  fi
  sleep 1
  _WAIT=$(( _WAIT + 1 ))
done

_log "collecting disks..."
collect_disks "${DISKS}"
if [ ! -s "${DISKS}" ]; then
  rm -f "${DISKS}"
  _log "No drives found — exiting."
  exit 0
fi
_log "drives collected: $(wc -l <"${DISKS}" | tr -d ' ') entries"

DISKS_DEDUP="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0
awk -F'\t' '!seen[$2"\t"$3]++' "${DISKS}" >"${DISKS_DEDUP}"
_log "unique model+firmware combinations for DB patch: $(wc -l <"${DISKS_DEDUP}" | tr -d ' ')"

for DB in /var/lib/disk-compatibility/*_v*.db; do
  [ -f "${DB}" ] || continue
  patch_database "${DB}" "${DISKS_DEDUP}"
done
rm -f "${DISKS_DEDUP}"

_log "patching storage settings..."
patch_storage_settings
_log "patching StorageManager UI..."
patch_storagemanager_ui
_log "clearing pool compatibility..."
clear_pool_compatibility

_log "refreshing runtime compatibility..."
refresh_runtime "${DISKS}"
set_m2_pool_support

rm -f "${DISKS}"

if [ "$noupdate" = "yes" ]; then
  _log "disabling drive DB auto-updates..."
  _disable_dbupdates
fi

if [ "$ram" = "yes" ]; then
  val="$(_get support_memory_compatibility)"
  if [ -n "$val" ]; then
    [ "$val" != "no" ] && _set support_memory_compatibility "no" && \
      _log "support_memory_compatibility disabled"
  else
    memcheck=/usr/lib/systemd/system/SynoMemCheck.service
    if [ -f "$memcheck" ]; then
      cur="$("$GKV" "$memcheck" ExecStart)"
      if [ "$cur" != "/bin/true" ]; then
        "$SKV" "$memcheck" ExecStart /bin/true
        _log "SynoMemCheck disabled"
      fi
    fi
  fi
fi

if [ "$wdda" = "yes" ]; then
  val="$(_get support_wdda)"
  if [ "$val" = "yes" ]; then
    _set support_wdda "no"
    _log "support_wdda disabled"
  fi
fi

if [ "$ssd" = "yes" ]; then
  _apply_ssd_writemostly
fi

if [ "$ihm" = "yes" ] && [ "$(uname -m)" = "x86_64" ]; then
  _enable_ihm
fi

if [ "$pcie" = "yes" ]; then
  _log "enabling PCIe/M.2 adaptor card support..."
  _enable_pcie
fi

if [ "$dedup" = "yes" ]; then
  _log "enabling deduplication support..."
  _enable_dedup
fi

if systemctl is-active --quiet pkgctl-StorageManager.service 2>/dev/null; then
  systemctl restart pkgctl-StorageManager.service 2>/dev/null || true
  _log "StorageManager restarted to reload compatibility"
fi

_log "done."
exit 0
