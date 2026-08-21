#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Makes DSM accept every attached drive.
#
# hdddb patches the persistent layer: synoinfo.conf and the
# /var/lib/disk-compatibility/*.db files. That alone is not enough, because
# synostoraged evaluates each disk at boot and caches the verdict under
# /run/synostorage/disks/<dev>/. A disk it has already flagged keeps showing as
# unverified/incompatible in Storage Manager no matter what the db says.
#
# This addon patches both layers, then refreshes the runtime state so the
# change applies without a reboot.

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

RUNTIME_ROOT="/run/synostorage/disks"
LOCK_RUNTIME="${DISKCOMPAT_LOCK:-0}"

_log() {
  echo "diskcompat: ${*}"
}

disk_size_gb() {
  SECTORS="$(tr -d '\r\n' <"/sys/block/${1}/size" 2>/dev/null)"
  case "${SECTORS}" in
    *[!0-9]* | "") echo 0 ;;
    *) awk -v sectors="${SECTORS}" 'BEGIN { printf "%d\n", (sectors * 512 / 1000 / 1000 / 1000) + 0.5 }' ;;
  esac
}

# synostoraged creates the per-disk directories a little after the service
# starts. Without this the first boot patches nothing and the drives stay
# unverified until the next one.
wait_for_runtime() {
  for _ in $(seq 1 30); do
    for D in "${RUNTIME_ROOT}"/*; do
      [ -d "${D}" ] && return 0
    done
    sleep 2
  done
  _log "runtime disk directories did not appear, patching databases only"
  return 1
}

collect_disks() {
  TMP="${1}"
  : >"${TMP}"

  for DISK_DIR in "${RUNTIME_ROOT}"/*; do
    [ -d "${DISK_DIR}" ] || continue
    DEV="$(basename "${DISK_DIR}")"
    MODEL="$([ -f "${DISK_DIR}/model" ] && tr -d '\r\n' <"${DISK_DIR}/model" 2>/dev/null)"
    [ -n "${MODEL}" ] || MODEL="$([ -f "${DISK_DIR}/real_model" ] && tr -d '\r\n' <"${DISK_DIR}/real_model" 2>/dev/null)"
    [ -n "${MODEL}" ] || MODEL="Unknown"
    FIRM="$([ -f "${DISK_DIR}/firm" ] && tr -d '\r\n' <"${DISK_DIR}/firm" 2>/dev/null)"
    SIZE="$(disk_size_gb "${DEV}")"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done

  for BLOCK_DIR in /sys/block/*; do
    [ -d "${BLOCK_DIR}" ] || continue
    DEV="$(basename "${BLOCK_DIR}")"
    case "${DEV}" in
      sata* | sas* | sd* | nvme*) ;;
      *) continue ;;
    esac
    grep -q "^${DEV}	" "${TMP}" 2>/dev/null && continue
    MODEL="$([ -f "${BLOCK_DIR}/device/model" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/model" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${MODEL}" ] || MODEL="Unknown"
    FIRM="$([ -f "${BLOCK_DIR}/device/firmware_rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/firmware_rev" 2>/dev/null)"
    [ -n "${FIRM}" ] || FIRM="$([ -f "${BLOCK_DIR}/device/rev" ] && tr -d '\r\n' <"${BLOCK_DIR}/device/rev" 2>/dev/null)"
    FIRM="$(printf '%s' "${FIRM}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    SIZE="$(disk_size_gb "${DEV}")"
    printf '%s\t%s\t%s\t%s\n' "${DEV}" "${MODEL}" "${FIRM}" "${SIZE}" >>"${TMP}"
  done
}

patch_database() {
  DB="${1}"
  DISKS="${2}"
  SUPPORT_INTERVAL='{"compatibility":"support","not_yet_rolling_status":"support","fw_dsm_update_status_notify":false,"barebone_installable":true,"barebone_installable_v2":"auto","smart_test_ignore":true,"smart_attr_ignore":true}'
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

# DSM may set the immutable bit on these, and a previous run of this script
# will have done so when DISKCOMPAT_LOCK=1.
_unlock() {
  [ -e "${1}" ] || return 0
  chattr -i "${1}" 2>/dev/null || true
}

_write() {
  _unlock "${1}"
  printf '%s' "${2}" >"${1}" 2>/dev/null || true
}

refresh_runtime() {
  DISKS="${1}"
  SUPPORT_ACTION='{"allow_auto_repair":true,"allow_binding":true,"allow_detected_scan":true,"allow_ma_create":true,"cache_rescue_selectable":"yes","cache_selectable":"yes","cache_status":"healthy","disk_status":"support","hide_alloc_status":false,"hide_fw_version":false,"hide_is4Kn":false,"hide_remain_life":false,"hide_sb_days_left":false,"hide_serial":false,"hide_temperature":false,"hide_unc":false,"legacy_cache_rescue_selectable":"yes","legacy_cache_selectable":"yes","legacy_cache_status":"healthy","notification":false,"notify_health_status":true,"notify_lifetime":true,"notify_unc":true,"pool_rescue_selectable":"yes","pool_selectable":"yes","pool_status":"healthy","send_health_report":true,"show_lifetime_chart":true}'
  COUNT=0
  while IFS="$(printf '\t')" read -r DEV MODEL FIRM SIZE; do
    DISK_DIR="${RUNTIME_ROOT}/${DEV}"
    [ -d "${DISK_DIR}" ] || continue

    # Drop the locks first, otherwise synostoraged keeps the cached verdict.
    _unlock "${DISK_DIR}/compatibility.lock"
    _unlock "${DISK_DIR}/compatibility_action.lock"
    rm -f "${DISK_DIR}/compatibility.lock" "${DISK_DIR}/compatibility_action.lock" 2>/dev/null || true

    _write "${DISK_DIR}/compatibility" "support"
    _write "${DISK_DIR}/force_compatibility" "support"
    _write "${DISK_DIR}/adv_status" "support"
    _write "${DISK_DIR}/compatibility_action" "${SUPPORT_ACTION}"
    _write "${DISK_DIR}/smart_attr_ignore" "1"
    _write "${DISK_DIR}/smart_test_ignore" "1"

    # Optional: make the files immutable so a later DSM re-evaluation cannot
    # undo them. Off by default - an immutable file in /run can make
    # synostoraged fail its own writes. Set DISKCOMPAT_LOCK=1 to enable.
    if [ "${LOCK_RUNTIME}" = "1" ]; then
      for F in compatibility force_compatibility adv_status compatibility_action; do
        [ -e "${DISK_DIR}/${F}" ] && chattr +i "${DISK_DIR}/${F}" 2>/dev/null || true
      done
    fi

    COUNT=$((COUNT + 1))
  done <"${DISKS}"
  _log "refreshed runtime state for ${COUNT} disk(s)"
}

if [ "${1}" = "--restore" ]; then
  # Only the immutable bits need undoing. The db files are regenerated by DSM
  # and the runtime tree lives in /run, so both are gone after a reboot.
  for DISK_DIR in "${RUNTIME_ROOT}"/*; do
    [ -d "${DISK_DIR}" ] || continue
    for F in compatibility force_compatibility adv_status compatibility_action; do
      _unlock "${DISK_DIR}/${F}"
    done
  done
  _log "removed immutable flags from runtime disk state"
  exit 0
fi

for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "support_disk_compatibility" "yes"; done
for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "forbid_unsupport_extdev" "no"; done

wait_for_runtime

DISKS="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0
collect_disks "${DISKS}"
[ -s "${DISKS}" ] || {
  _log "no disks found"
  rm -f "${DISKS}"
  exit 0
}

for DB in /var/lib/disk-compatibility/*_v*.db; do
  [ -f "${DB}" ] || continue
  patch_database "${DB}" "${DISKS}"
done

patch_storage_settings
clear_pool_compatibility
refresh_runtime "${DISKS}"
rm -f "${DISKS}"

exit 0
