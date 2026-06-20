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
#   -p | --pcie          No-op
#

# ── bootstrap ────────────────────────────────────────────────────────────────

if [ "$(basename "$BASH")" != "bash" ]; then
  echo "This script requires bash."; exit 1
fi
if [ "$(whoami)" != "root" ]; then
  echo "This script must be run as root."; exit 1
fi

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

# ── option parsing ────────────────────────────────────────────────────────────

noupdate=no
ram=no
wdda=no
ihm=no
ssd=no

for arg in "$@"; do
  case "$arg" in
    -n|--noupdate|--nodbupdate) noupdate=yes ;;
    -r|--ram)   ram=yes ;;
    -w|--wdda)  wdda=yes ;;
    -I|--ihm)   ihm=yes ;;
    -S|--ssd)   ssd=yes ;;
    -e|--email|-p|--pcie) ;;
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

# ── boot disk detection ───────────────────────────────────────────────────────

BOOTDISK=""
BOOTDISK_PART3="$(/sbin/blkid -L ARC3 2>/dev/null)"
if [ -n "$BOOTDISK_PART3" ]; then
  MM="$(stat -c '%t:%T' "$BOOTDISK_PART3" 2>/dev/null | \
    awk -F: '{printf "%d:%d", strtonum("0x"$1), strtonum("0x"$2)}')"
  BOOTDISK="$(awk -F= '/DEVNAME/{print $2}' "/sys/dev/block/$MM/uevent" 2>/dev/null)"
  BOOTDISK="${BOOTDISK%%[0-9]*}"
fi

_is_usb() {
  grep -q "[Uu][Ss][Bb]" "/sys/block/$1/device/uevent" 2>/dev/null ||
  awk -F= '/PHYSDEVPATH/{print $2}' "/sys/block/$1/uevent" 2>/dev/null | grep -qi usb
}

_trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# ── drive enumeration ─────────────────────────────────────────────────────────

collect_disks() {
  TMP="${1}"
  : >"${TMP}"

  # Primary: read from synostorage (already enumerated by DSM)
  for DISK_DIR in /run/synostorage/disks/*; do
    [ -d "${DISK_DIR}" ] || continue
    DEV="$(basename "${DISK_DIR}")"
    [ "$DEV" = "$BOOTDISK" ] && continue
    _is_usb "$DEV" && continue

    MODEL="$([ -f "${DISK_DIR}/model" ] && tr -d '\r\n' <"${DISK_DIR}/model" 2>/dev/null)"
    [ -n "${MODEL}" ] || MODEL="$([ -f "${DISK_DIR}/real_model" ] && tr -d '\r\n' <"${DISK_DIR}/real_model" 2>/dev/null)"
    [ -n "${MODEL}" ] || continue
    MODEL="$(_trim "$MODEL")"
    FIRM="$([ -f "${DISK_DIR}/firm" ] && tr -d '\r\n' <"${DISK_DIR}/firm" 2>/dev/null)"
    FIRM="$(_trim "$FIRM")"
    SIZE="$(disk_size_gb "${DEV}")"
    _log "  found (synostorage): ${DEV} model=${MODEL} firm=${FIRM} size=${SIZE}"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done

  # Fallback: scan /sys/block for drives not already listed
  for BLOCK_DIR in /sys/block/*; do
    [ -d "${BLOCK_DIR}" ] || continue
    DEV="$(basename "${BLOCK_DIR}")"
    case "${DEV}" in
      sata*|sd*|nvme*|sas*) ;;
      *) continue ;;
    esac
    [ "$DEV" = "$BOOTDISK" ] && continue
    _is_usb "$DEV" && continue
    grep -q "^${DEV}	" "${TMP}" 2>/dev/null && continue

    MODEL="$([ -f "${BLOCK_DIR}/device/model" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/model" 2>/dev/null)"
    MODEL="$(_trim "$MODEL")"
    [ -n "${MODEL}" ] || { _log "  skip (no model): ${DEV}"; continue; }

    # Strip known vendor prefixes
    for pfx in "WDC " "HGST " "TOSHIBA " "Hitachi " "SAMSUNG " "FUJITSU " "HCST " "APPLE HDD "; do
      MODEL="${MODEL#$pfx}"
    done
    MODEL="$(_trim "$MODEL")"

    FIRM="$([ -f "${BLOCK_DIR}/device/firmware_rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/firmware_rev" 2>/dev/null)"
    [ -n "${FIRM}" ] || FIRM="$([ -f "${BLOCK_DIR}/device/rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/rev" 2>/dev/null)"
    FIRM="$(_trim "$FIRM")"
    SIZE="$(disk_size_gb "${DEV}")"
    _log "  found (sysblock): ${DEV} model=${MODEL} firm=${FIRM} size=${SIZE}"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done
}

# ── database patching ─────────────────────────────────────────────────────────

patch_database() {
  DB="${1}"
  DISKS="${2}"
  SUPPORT_INTERVAL='{"compatibility":"support","not_yet_rolling_status":"support","fw_dsm_update_status_notify":false,"barebone_installable":true,"barebone_installable_v2":"auto","smart_test_ignore":true,"smart_attr_ignore":true}'
  if ! jq -e '.disk_compatbility_info | type == "object"' "${DB}" >/dev/null 2>&1; then
    return 0
  fi

  TMP="${DB}.tmp.$$"
  if ! jq -c . "${DB}" >"${TMP}" 2>/dev/null; then
    cp -p "${DB}" "${TMP}" || return 0
  fi
  while IFS="$(printf '\t')" read -r DEV MODEL FIRM SIZE; do
    [ -n "${MODEL}" ] || continue
    case "${SIZE}" in *[!0-9]* | "") SIZE=0 ;; esac
    jq -c \
      --arg model "${MODEL}" \
      --arg firm "${FIRM}" \
      --argjson size "${SIZE}" \
      --argjson interval "${SUPPORT_INTERVAL}" \
      '
      if .disk_compatbility_info[$model] == null then
        .disk_compatbility_info[$model] = {}
      else . end
      | if .disk_compatbility_info[$model].default == null then
          .disk_compatbility_info[$model].default = {}
        else . end
      | if $size > 0 then .disk_compatbility_info[$model].default.size_gb = $size else . end
      | .disk_compatbility_info[$model].default.compatibility_interval = [$interval]
      | if $firm != "" then
          if .disk_compatbility_info[$model][$firm] == null then
            .disk_compatbility_info[$model][$firm] = {}
          else . end
          | .disk_compatbility_info[$model][$firm].fw_buildnumber = (.disk_compatbility_info[$model][$firm].fw_buildnumber // 1)
          | .disk_compatbility_info[$model][$firm].compatibility_interval = [$interval]
        else . end
      ' "${TMP}" >"${TMP}.new" && mv -f "${TMP}.new" "${TMP}" || {
      rm -f "${TMP}" "${TMP}.new"
      return 0
    }
  done <"${DISKS}"

  chmod 644 "${TMP}" 2>/dev/null || true
  mv -f "${TMP}" "${DB}"
}

patch_storage_settings() {
  DB="/var/lib/storage_setting/general_settings.db"
  [ -f "${DB}" ] || return 0
  jq -e . "${DB}" >/dev/null 2>&1 || return 0

  TMP="${DB}.tmp.$$"
  jq -c '.settings.allow_new_hcl_as_normal = {"dsm_ver":[],"values":[true]}' "${DB}" >"${TMP}" && mv -f "${TMP}" "${DB}"
}

clear_pool_compatibility() {
  for FILE in /var/lib/space/pool_compatibility /var/lib/space/pool_compatibility_legacy; do
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
  DISKS="${1}"
  SUPPORT_ACTION='{"allow_auto_repair":true,"allow_binding":true,"allow_detected_scan":true,"allow_ma_create":true,"cache_rescue_selectable":"yes","cache_selectable":"yes","cache_status":"healthy","disk_status":"support","hide_alloc_status":false,"hide_fw_version":false,"hide_is4Kn":false,"hide_remain_life":false,"hide_sb_days_left":false,"hide_serial":false,"hide_temperature":false,"hide_unc":false,"legacy_cache_rescue_selectable":"yes","legacy_cache_selectable":"yes","legacy_cache_status":"healthy","notification":false,"notify_health_status":true,"notify_lifetime":true,"notify_unc":true,"pool_rescue_selectable":"yes","pool_selectable":"yes","pool_status":"healthy","send_health_report":true,"show_lifetime_chart":true}'
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

# ── IronWolf Health Management ────────────────────────────────────────────────

_enable_ihm() {
  val="$(_get support_ihm)"
  [ "$val" != "yes" ] && _set support_ihm "yes" && _log "support_ihm enabled"

  for _sgpath in /sys/class/scsi_generic/sg*; do
    [ -e "$_sgpath" ] || continue
    _sgname="$(basename "$_sgpath")"
    if [ ! -c "/dev/$_sgname" ] && [ -f "$_sgpath/dev" ]; then
      _sgmaj="$(cut -d: -f1 < "$_sgpath/dev")"
      _sgmin="$(cut -d: -f2 < "$_sgpath/dev")"
      mknod "/dev/$_sgname" c "$_sgmaj" "$_sgmin" >/dev/null 2>&1 && \
        _log "created /dev/$_sgname ($_sgmaj:$_sgmin)"
    fi
  done

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
done

DISKS="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0

# Wait for synostorage to enumerate disks (up to 60s)
_WAIT=0
while [ ! -d "/run/synostorage/disks" ] || [ -z "$(ls /run/synostorage/disks/ 2>/dev/null)" ]; do
  if [ "${_WAIT}" -ge 60 ]; then
    _log "synostorage not ready after 60s, proceeding with fallback..."
    break
  fi
  sleep 2
  _WAIT=$(( _WAIT + 2 ))
done

_log "collecting disks..."
collect_disks "${DISKS}"
if [ ! -s "${DISKS}" ]; then
  rm -f "${DISKS}"
  _log "No drives found — exiting."
  exit 0
fi
_log "drives collected: $(wc -l <"${DISKS}") entries"

for DB in /var/lib/disk-compatibility/*.db; do
  [ -f "${DB}" ] || continue
  patch_database "${DB}" "${DISKS}"
done

_log "patching storage settings..."
patch_storage_settings
_log "clearing pool compatibility..."
clear_pool_compatibility
_log "refreshing runtime compatibility..."
refresh_runtime "${DISKS}"
_log "setting M.2 pool support..."
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

if [ -f /usr/syno/sbin/synostgdisk ]; then
  /usr/syno/sbin/synostgdisk --check-all-disks-compatibility
  _log "synostgdisk compatibility check done (exit $?)"
fi

# Restart StorageManager to re-read compatibility state
if systemctl is-active --quiet pkgctl-StorageManager.service 2>/dev/null; then
  systemctl restart pkgctl-StorageManager.service 2>/dev/null || true
  _log "StorageManager restarted to reload compatibility"
fi

_log "done."
exit 0
