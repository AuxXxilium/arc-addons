#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Adds currently installed drives to DSM's disk compatibility database and
# clears unsupported-drive storage pool warnings. Runs on boot and whenever
# a block device is added.
#

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

disk_size_gb() {
  SECTORS="$(tr -d '\r\n' <"/sys/block/${1}/size" 2>/dev/null)"
  case "${SECTORS}" in
    *[!0-9]* | "") echo 0 ;;
    *) awk -v sectors="${SECTORS}" 'BEGIN { printf "%d\n", (sectors * 512 / 1000 / 1000 / 1000) + 0.5 }' ;;
  esac
}

collect_disks() {
  TMP="${1}"
  : >"${TMP}"

  for DISK_DIR in /run/synostorage/disks/*; do
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
      sata* | sd* | nvme*) ;;
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

for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "support_disk_compatibility" "yes"; done
for F in "/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "forbid_unsupport_extdev" "no"; done

DISKS="$(mktemp /tmp/diskcompat.XXXXXX)" || exit 0
collect_disks "${DISKS}"
[ -s "${DISKS}" ] || {
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
