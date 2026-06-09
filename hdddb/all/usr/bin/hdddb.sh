#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Patches DSM disk compatibility databases so that any installed drive is
# recognised as supported.  Replaces the upstream Synology_HDD_db script with
# a minimal, ARC-specific implementation that covers only what ARC needs.
#
# Flags (compatible subset of the original script):
#   -n | --noupdate      Prevent DSM updating the drive databases
#   -r | --ram           Disable memory-compatibility checking
#   -w | --wdda          Disable WD Device Analytics warnings
#   -I | --ihm           Enable / update IronWolf Health Management
#   -e | --email         No-op (kept for call-site compatibility)
#   -S | --ssd           No-op (write_mostly not used in ARC)
#   -p | --pcie          No-op (storage panel handled by storagepanel addon)
#

# ── bootstrap ────────────────────────────────────────────────────────────────

if [ "$(basename "$BASH")" != "bash" ]; then
  echo "This script requires bash."; exit 1
fi
if [ "$(whoami)" != "root" ]; then
  echo "This script must be run as root."; exit 1
fi

GKV=/usr/syno/bin/synogetkeyvalue
SKV=/usr/syno/bin/synosetkeyvalue

# ── option parsing ────────────────────────────────────────────────────────────

noupdate=no
ram=no
wdda=no
ihm=no

for arg in "$@"; do
  case "$arg" in
    -n|--noupdate|--nodbupdate) noupdate=yes ;;
    -r|--ram)   ram=yes ;;
    -w|--wdda)  wdda=yes ;;
    -I|--ihm)   ihm=yes ;;
    -e|--email|-S|-p|--pcie|--ssd) ;;  # accepted, ignored
    *) ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────

SYNOINFO=/etc.defaults/synoinfo.conf

_get() { "$GKV" "$SYNOINFO" "$1"; }
_set() { "$SKV" "$SYNOINFO" "$1" "$2"; "$SKV" /etc/synoinfo.conf "$1" "$2"; }

_log() { echo "hdddb: $*"; }

# ── drive enumeration ─────────────────────────────────────────────────────────

# Detect ARC boot disk so we never add it to the DB
BOOTDISK_PART3="$(/sbin/blkid -L ARC3 2>/dev/null)"
if [ -n "$BOOTDISK_PART3" ]; then
  MM="$(stat -c '%t:%T' "$BOOTDISK_PART3" 2>/dev/null | \
    awk -F: '{printf "%d:%d", strtonum("0x"$1), strtonum("0x"$2)}')"
  BOOTDISK="$(awk -F= '/DEVNAME/{print $2}' "/sys/dev/block/$MM/uevent" 2>/dev/null)"
  BOOTDISK="${BOOTDISK%%[0-9]*}"  # strip partition suffix → base device
fi

_is_usb() {
  grep -q "[Uu][Ss][Bb]" "/sys/block/$1/device/uevent" 2>/dev/null ||
  awk -F= '/PHYSDEVPATH/{print $2}' "/sys/block/$1/uevent" 2>/dev/null | grep -qi usb
}

_trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

_size_gb() {
  # $1: block device basename (sata1, sda, nvme0n1 …)
  local raw
  raw=$(synodisk --info "/dev/$1" 2>/dev/null | grep 'Total capacity' | awk '{print $4}')
  [ -z "$raw" ] && { echo 0; return; }
  # round to nearest 4 GB to avoid 6001/6000 drift
  awk -v r="$raw" 'BEGIN{gb=r*1.073741824; printf "%d\n", int(gb/4+0.5)*4}'
}

# Collect drives: hdds[] for SATA/SAS, nvmes[] for NVMe
# Each entry: "model,firmware,size_gb"
declare -a hdds nvmes

for BLKPATH in /sys/block/*; do
  DEV="$(basename "$BLKPATH")"

  # Skip non-storage, loop, dm, md, boot disk
  case "$DEV" in
    sd[a-z]|sd[a-z][a-z]|sata[0-9]*|sas[0-9]*|hd[a-z]) ;;
    nvme[0-9]*n[0-9]*) ;;
    *) continue ;;
  esac

  [ "$DEV" = "$BOOTDISK" ] && continue
  _is_usb "$DEV" && continue

  if [[ "$DEV" =~ ^nvme ]]; then
    model="$(_trim "$(cat "$BLKPATH/device/model" 2>/dev/null)")"
    fw="$(_trim "$(cat "$BLKPATH/device/firmware_rev" 2>/dev/null)")"
    [ -z "$model" ] || [ -z "$fw" ] && continue
    size="$(_size_gb "$DEV")"
    nvmes+=("${model},${fw},${size}")
  else
    model="$(_trim "$(cat "$BLKPATH/device/model" 2>/dev/null)")"
    [ -z "$model" ] && continue

    # Strip known vendor prefixes that appear in the model field
    for pfx in "WDC " "HGST " "TOSHIBA " "Hitachi " "SAMSUNG " "FUJITSU " "HCST " "APPLE HDD "; do
      model="${model#$pfx}"
    done
    model="$(_trim "$model")"

    # Firmware: try syno_hdd_util first, fall back to smartctl
    fw="$(/usr/syno/bin/syno_hdd_util --ssd_detect 2>/dev/null | \
         grep "/dev/$DEV " | awk '{print $(NF-3)}')"
    if [ -z "$fw" ]; then
      fw="$(smartctl -a -d ata -T permissive "/dev/$DEV" 2>/dev/null | \
            grep -i firmware | awk '{print $NF}')"
    fi
    [ -z "$model" ] || [ -z "$fw" ] && continue

    size="$(_size_gb "$DEV")"

    # M.2 SATA SSD goes into nvmes[], regular drives into hdds[]
    if /usr/syno/bin/synodisk --enum -t cache 2>/dev/null | grep -q "/dev/$DEV"; then
      nvmes+=("${model},${fw},${size}")
    else
      hdds+=("${model},${fw},${size}")
    fi
  fi
done

# Deduplicate
mapfile -t hdds  < <(printf '%s\n' "${hdds[@]}"  | sort -u)
mapfile -t nvmes < <(printf '%s\n' "${nvmes[@]}" | sort -u)

_log "SATA/SAS drives found: ${#hdds[@]}"
for d in "${hdds[@]}";  do _log "  $d GB"; done
_log "NVMe/M.2 drives found: ${#nvmes[@]}"
for d in "${nvmes[@]}"; do _log "  $d GB"; done

if [ "${#hdds[@]}" -eq 0 ] && [ "${#nvmes[@]}" -eq 0 ]; then
  _log "No drives found — exiting."
  exit 2
fi

# ── database injection ────────────────────────────────────────────────────────

DBPATH=/var/lib/disk-compatibility

# Build the JSON fragment for one firmware entry
# $1 model  $2 fwrev  $3 size_gb
_db_entry() {
  local model="$1" fw="$2" size="$3"
  local common
  common='"compatibility_interval":[{'
  common+="\"compatibility\":\"support\","
  common+='"not_yet_rolling_status":"support",'
  common+='"fw_dsm_update_status_notify":false,'
  common+='"barebone_installable":true,'
  common+='"barebone_installable_v2":"auto",'
  common+='"smart_test_ignore":false,'
  common+='"smart_attr_ignore":false}]}'
  printf '"%s":{"fw_buildnumber":1,%s' "$fw" "$common"
}

# Inject model+fw into one db file (DSM 7 format only)
# $1 "model,fw,size"  $2 db file path
_update_db() {
  local entry="$1" dbfile="$2"
  local model fw size
  model="$(cut -d, -f1 <<< "$entry")"
  fw="$(cut -d, -f2 <<< "$entry")"
  size="$(cut -d, -f3 <<< "$entry")"

  # Only handle DSM 7 format
  grep -qF '{"disk_compatbility_info":' "$dbfile" 2>/dev/null || return

  # Compact if needed (DSM 7.3+ writes pretty-printed JSON)
  if [ "$(wc -l < "$dbfile")" -gt 1 ]; then
    jq -c . "$dbfile" > "$dbfile.tmp" && mv "$dbfile.tmp" "$dbfile"
  fi

  # Already present?
  if jq -e --arg m "$model" --arg f "$fw" \
      '.disk_compatbility_info[$m] | has($f)' "$dbfile" >/dev/null 2>&1; then
    _log "  already in $(basename "$dbfile"): $model ($fw)"
    return
  fi

  local fw_json default_json
  fw_json="$(_db_entry "$model" "$fw" "$size")"
  default_json="\"default\":{\"size_gb\":${size},$( \
    printf '"compatibility_interval":[{"compatibility":"support","not_yet_rolling_status":"support","fw_dsm_update_status_notify":false,"barebone_installable":true,"barebone_installable_v2":"auto","smart_test_ignore":false,"smart_attr_ignore":false}]}')"

  # Escape model for sed
  local msed="${model//\"/\\\"}"
  msed="${msed//\//\\/}"
  local fwsed="${fw_json//\//\\/}"

  if grep -qF '"disk_compatbility_info":{}' "$dbfile"; then
    # Empty db
    sed -i "s/\"disk_compatbility_info\":{}/\"disk_compatbility_info\":{\"${msed}\":{${fwsed},${default_json}}/" "$dbfile"
  elif jq -e --arg m "$model" '.disk_compatbility_info[$m]' "$dbfile" >/dev/null 2>&1; then
    # Model exists, insert fw
    sed -i "s/\"${msed}\":{/\"${msed}\":{${fwsed},/" "$dbfile"
  else
    # Append model
    sed -i "s/}}}$/},\"${msed}\":{${fwsed},${default_json}}/" "$dbfile"
  fi

  if jq -e --arg m "$model" --arg f "$fw" \
      '.disk_compatbility_info[$m] | has($f)' "$dbfile" >/dev/null 2>&1; then
    _log "  added to $(basename "$dbfile"): $model ($fw)"
  else
    _log "  FAILED to add to $(basename "$dbfile"): $model ($fw)"
  fi
}

# Fix unverified entries
_fix_unverified() {
  local f="$1"
  if grep -q 'unverified' "$f" 2>/dev/null; then
    sed -i 's/unverified/support/g' "$f"
    _log "  fixed unverified entries in $(basename "$f")"
  fi
}

# Backup a db file once
_backup() {
  [ -f "$1.bak" ] || cp -p "$1" "$1.bak"
}

mapfile -t db1list < <(find "$DBPATH" -maxdepth 1 -name "*_host*.db"     | sort)
mapfile -t db2list < <(find "$DBPATH" -maxdepth 1 -name "*_host*.db.new" | sort)

if [ "${#db1list[@]}" -eq 0 ]; then
  _log "No host db files found in $DBPATH — exiting."
  exit 4
fi

for f in "${db1list[@]}" "${db2list[@]}"; do
  _backup "$f"
  _fix_unverified "$f"
done

for entry in "${hdds[@]}" "${nvmes[@]}"; do
  for f in "${db1list[@]}" "${db2list[@]}"; do
    _update_db "$entry" "$f"
  done
done

# ── m2_pool_support ───────────────────────────────────────────────────────────

for d in /run/synostorage/disks/nvme*/m2_pool_support; do
  [ -f "$d" ] && echo -n 1 > "$d"
done

# ── synoinfo.conf patches ─────────────────────────────────────────────────────

# Disable drive DB auto-updates
_disable_dbupdates() {
  local dsmmajor dsmminor
  dsmmajor="$("$GKV" /etc.defaults/VERSION majorversion)"
  dsmminor="$("$GKV" /etc.defaults/VERSION minorversion)"

  if [ "${dsmmajor}${dsmminor}" -lt 73 ] 2>/dev/null; then
    # DSM < 7.3: redirect update URL
    local cur
    cur="$(_get drive_db_test_url)"
    if [ "$cur" != "127.0.0.1" ]; then
      _set drive_db_test_url "127.0.0.1"
      _log "drive DB auto-updates disabled (drive_db_test_url)"
    fi
  else
    # DSM 7.3+: bump SynoOnlinePack version so it never auto-updates
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

[ "$noupdate" = "yes" ] && _disable_dbupdates

# Disable memory compatibility checking
if [ "$ram" = "yes" ]; then
  val="$(_get support_memory_compatibility)"
  if [ -n "$val" ]; then
    [ "$val" != "no" ] && _set support_memory_compatibility "no" && \
      _log "support_memory_compatibility disabled"
  else
    # Older models use SynoMemCheck.service
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

# Disable WDDA
if [ "$wdda" = "yes" ]; then
  val="$(_get support_wdda)"
  if [ "$val" = "yes" ]; then
    _set support_wdda "no"
    _log "support_wdda disabled"
  fi
fi

# ── IronWolf Health Management ────────────────────────────────────────────────

if [ "$ihm" = "yes" ] && [ "$(uname -m)" = "x86_64" ]; then
  val="$(_get support_ihm)"
  [ "$val" != "yes" ] && _set support_ihm "yes" && _log "support_ihm enabled"

  DHM=/usr/syno/sbin/dhm_tool
  BUNDLED="$(dirname "$0")/bin/dhm_tool"
  [ ! -f "$BUNDLED" ] && BUNDLED=/usr/syno/sbin/dhm_tool.bundled

  if [ -f "$BUNDLED" ] && [ "$BUNDLED" != "$DHM" ]; then
    cur_ver="$(dhm_tool --version 2>/dev/null | grep 'Utility Version' | awk '{print $NF}')"
    if ! printf '%s\n%s\n' "2.5.1" "$cur_ver" | sort --check=quiet --version-sort 2>/dev/null; then
      cp -p "$BUNDLED" "$DHM" && chmod 755 "$DHM"
      _log "dhm_tool updated to $("$DHM" --version 2>/dev/null | grep 'Utility Version' | awk '{print $NF}')"
    fi
  fi
fi

# ── trigger DSM compatibility check ──────────────────────────────────────────

if [ -f /usr/syno/sbin/synostgdisk ]; then
  /usr/syno/sbin/synostgdisk --check-all-disks-compatibility
  _log "synostgdisk compatibility check done (exit $?)"
fi

_log "done."
exit 0
