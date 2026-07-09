#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Patches DSM disk compatibility databases so that any installed drive is
# recognised as supported. A reboot is required for changes to take effect.
#
# Based on https://github.com/007revad/Synology_HDD_db
#
# Flags:
#   -n | --noupdate      Prevent DSM updating the drive databases
#   -r | --ram           Disable memory-compatibility checking
#   -w | --wdda          Disable WD Device Analytics warnings
#   -I | --ihm           Enable / update IronWolf Health Management
#   -S | --ssd           Set write_mostly on HDDs when internal SSDs are present
#   -d | --dedup         Enable Btrfs deduplication for non-Synology drives (patches libhwcontrol)
#   -f | --force         Disable support_disk_compatibility entirely instead of patching per-drive
#

# ── bootstrap ────────────────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -x /usr/bin/arcsu ]; then
    echo "Error: This script must be run as root or with 'arcsu'."
    exit 1
  fi
  exec env ARCSU_ACTIVE=1 arcsu "$0" "$@"
fi

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

# ── option parsing ────────────────────────────────────────────────────────────

noupdate=no
ram=no
wdda=no
ihm=no
ssd=no
dedup=no
force=no

for arg in "$@"; do
  case "$arg" in
    -n|--noupdate|--nodbupdate) noupdate=yes ;;
    -r|--ram)   ram=yes ;;
    -w|--wdda)  wdda=yes ;;
    -I|--ihm)   ihm=yes ;;
    -S|--ssd)   ssd=yes ;;
    -d|--dedup) dedup=yes ;;
    -f|--force) force=yes ;;
    *) ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────

SYNOINFO=/etc.defaults/synoinfo.conf

_get() { "$GKV" "$SYNOINFO" "$1"; }
_set() { "$SKV" "$SYNOINFO" "$1" "$2"; "$SKV" /etc/synoinfo.conf "$1" "$2"; }
_log() { echo "hdddb: $*"; }

_has_hba_driver() {
  lspci -n 2>/dev/null | grep -qE ' (0100|0104|0107):'
}

_count_disks() {
  local c=0 f
  for f in ${1}; do [ -e "${f}" ] && c=$((c + 1)); done
  echo "${c}"
}

_wait_hba_disks_stable() {
  _has_hba_driver || return 0

  local globs="/sys/block/sata* /sys/block/sas* /sys/block/sd*"
  _count() {
    local total=0 g
    for g in ${globs}; do total=$((total + $(_count_disks "${g}"))); done
    echo "${total}"
  }

  local prev cur stable_rounds=0 i=0
  prev="$(_count)"
  while [ "${i}" -lt 100 ]; do
    sleep 3
    cur="$(_count)"
    if [ "${cur}" = "${prev}" ]; then
      stable_rounds=$((stable_rounds + 1))
      [ "${stable_rounds}" -ge 5 ] && break
    else
      stable_rounds=0
      prev="${cur}"
    fi
    i=$((i + 1))
  done
  _log "HBA disks settled at count ${cur}"
}

# ── drive size ────────────────────────────────────────────────────────────────

disk_size_gb() {
  SECTORS="$(tr -d '\r\n' <"/sys/block/${1}/size" 2>/dev/null)"
  case "${SECTORS}" in
    *[!0-9]* | "") echo 0 ;;
    *) awk -v sectors="${SECTORS}" 'BEGIN { printf "%d\n", (sectors * 512 / 1000 / 1000 / 1000) + 0.5 }' ;;
  esac
}

# ── drive model normalisation ─────────────────────────────────────────────────

# Strip vendor prefixes that /sys/block/*/device/model reports but that the
# disk-compatibility DB keys drives without (e.g. "WDC WD40EFZX-..." -> "WD40EFZX-...").
# ATA/SCSI INQUIRY vendor/product fields are fixed-width and space-padded, so the
# raw string can have runs of multiple spaces between vendor and product (e.g.
# "VMware   Virtual disk") — collapse those to single spaces first.
#
# $2 (device basename) selects whether the "VMware " prefix is stripped: DSM's
# own disk-compatibility DBs key VMware's emulated SATA/SCSI virtual disks
# without the vendor prefix ("Virtual disk", "Virtual SATA Hard Drive") but keep
# it for its NVMe disks ("VMware Virtual NVMe Disk") — matching the live model
# string to the wrong convention leaves the disk permanently "unverified" even
# though a correct entry already exists in the DB.
fix_drive_model() {
  local m="$1" dev="${2:-}"
  m="$(printf '%s' "${m}" | sed 's/[[:space:]]\{1,\}/ /g')"
  case "${m}" in
    "WDC "*) m="${m#WDC }" ;;
    "HGST "*) m="${m#HGST }" ;;
    "TOSHIBA "*) m="${m#TOSHIBA }" ;;
    "HCST "*) m="${m#HCST }" ;;
    "Hitachi "*) m="${m#Hitachi }" ;;
    "SAMSUNG "*) m="${m#SAMSUNG }" ;;
    "FUJITSU "*) m="${m#FUJITSU }" ;;
    "VMware "*)
      case "${dev}" in
        nvme*) : ;; # DB keeps the "VMware " prefix for NVMe models
        *) m="${m#VMware }" ;;
      esac
      ;;
  esac
  printf '%s' "${m}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# ── drive enumeration ─────────────────────────────────────────────────────────

collect_disks() {
  TMP="${1}"
  : >"${TMP}"

  for BLOCK_DIR in /sys/block/*; do
    [ -d "${BLOCK_DIR}" ] || continue
    DEV="$(basename "${BLOCK_DIR}")"
    case "${DEV}" in
      sata* | sd* | nvme*) ;;
      *) continue ;;
    esac
    MODEL="$([ -f "${BLOCK_DIR}/device/model" ] && tr -cd '[:print:]' <"${BLOCK_DIR}/device/model" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${MODEL}" ] || continue
    MODEL="$(fix_drive_model "${MODEL}" "${DEV}")"
    # ATA/SCSI INQUIRY-style fields are fixed-width and space/NUL-padded; on some
    # (especially virtualized/emulated) devices the padding leaks embedded NULs or
    # non-ASCII bytes past the real string, which previously survived into FIRM and
    # showed up in the UI as e.g. "2.0 ????". Strip to printable ASCII only.
    FIRM="$([ -f "${BLOCK_DIR}/device/firmware_rev" ] && tr -cd '[:print:]' <"${BLOCK_DIR}/device/firmware_rev" 2>/dev/null)"
    [ -n "${FIRM}" ] || FIRM="$([ -f "${BLOCK_DIR}/device/rev" ] && tr -cd '[:print:]' <"${BLOCK_DIR}/device/rev" 2>/dev/null)"
    FIRM="$(printf '%s' "${FIRM}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    SIZE="$(disk_size_gb "${DEV}")"
    _log "  found: ${DEV} model=${MODEL} firm=${FIRM} size=${SIZE}"
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

  # Replace any remaining not_in_support/unverified values with support (catches fields jq didn't touch)
  sed -i 's/"not_in_support"/"support"/g; s/"unverified"/"support"/g' "${TMP}"

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

  if grep -wq "/addons/nvmevolume.sh\|/addons/nvmesystem.sh" "/addons/addons.sh" 2>/dev/null; then
    _log "dedup: libhwcontrol already patched by nvmevolume/nvmesystem, skipping"
    return
  fi

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
  if [ ! -f "${libhw}.bak-dedup" ]; then
    cp -p "$libhw" "${libhw}.bak-dedup" && _log "dedup: backed up $libhw"
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
  if [ "$force" = "yes" ]; then
    "$SKV" "${F}" "support_disk_compatibility" "no"
  else
    "$SKV" "${F}" "support_disk_compatibility" "yes"
  fi
  "$SKV" "${F}" "forbid_unsupport_extdev" "no"
  "$SKV" "${F}" "support_btrfs_dedupe" "yes"
done

_wait_hba_disks_stable

DISKS="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0

_log "collecting disks..."
collect_disks "${DISKS}"
if [ ! -s "${DISKS}" ]; then
  rm -f "${DISKS}"
  _log "No drives found — exiting."
  exit 0
fi
_log "drives collected: $(wc -l <"${DISKS}" | tr -d ' ') entries"

if grep -q "^nvme" "${DISKS}"; then
  for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do
    "$SKV" "${F}" "supportnvme" "yes"
    "$SKV" "${F}" "support_m2_pool" "yes"
  done
  _log "NVMe drives present: supportnvme/support_m2_pool enabled"
fi

DISKS_DEDUP="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0
awk -F'\t' '!seen[$2"\t"$3]++' "${DISKS}" >"${DISKS_DEDUP}"
_log "unique model+firmware combinations for DB patch: $(wc -l <"${DISKS_DEDUP}" | tr -d ' ')"

for DB in /var/lib/disk-compatibility/*_v*.db; do
  [ -f "${DB}" ] || continue
  patch_database "${DB}" "${DISKS_DEDUP}"
done
rm -f "${DISKS_DEDUP}" "${DISKS}"

_log "patching storage settings..."
patch_storage_settings

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

if [ "$dedup" = "yes" ]; then
  _log "enabling deduplication support..."
  _enable_dedup
fi

_log "done. Reboot required for changes to take effect."
exit 0
