#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# SYNC consts.sh
PART1_PATH="/mnt/p1"
PART2_PATH="/mnt/p2"
PART3_PATH="/mnt/p3"
#DSMROOT_PATH="/mnt/dsmroot"
TMP_PATH="/tmp"

#UNTAR_PAT_PATH="${TMP_PATH}/pat"
#RAMDISK_PATH="${TMP_PATH}/ramdisk"
#LOG_FILE="${TMP_PATH}/log.txt"

USER_CONFIG_FILE="${PART1_PATH}/user-config.yml"
GRUB_PATH="${PART1_PATH}/boot/grub"

ORI_ZIMAGE_FILE="${PART2_PATH}/zImage"
ORI_RDGZ_FILE="${PART2_PATH}/rd.gz"

ARC_BZIMAGE_FILE="${PART3_PATH}/bzImage-arc"
ARC_RAMDISK_FILE="${PART3_PATH}/initrd-arc"
MOD_ZIMAGE_FILE="${PART3_PATH}/zImage-dsm"
MOD_RDGZ_FILE="${PART3_PATH}/initrd-dsm"

CKS_PATH="${PART3_PATH}/custom"
LKMS_PATH="${PART3_PATH}/lkms"
ADDONS_PATH="${PART3_PATH}/addons"
MODULES_PATH="${PART3_PATH}/modules"
USER_UP_PATH="${PART3_PATH}/users"
SCRIPTS_PATH="${PART3_PATH}/scripts"

# Modify KVER for Epyc7002
if [ "${PLATFORM}" == "epyc7002" ]; then
  KVERP="${PRODUCTVER}-${KVER}"
else
  KVERP="${KVER}"
fi

# SYNC configFile.sh

# Read key value from yaml config file
# 1 - Path of key
# 2 - Path of yaml config file
# Return Value
function readConfigKey() {
  RESULT=$(yq eval '.'${1}' | explode(.)' "${2}" 2>/dev/null)
  [ "${RESULT}" == "null" ] && echo "" || echo ${RESULT}
}

# Read Entries as map(key=value) from yaml config file
# 1 - Path of key
# 2 - Path of yaml config file
# Returns map of values
function readConfigMap() {
  yq eval '.'${1}' | explode(.) | to_entries | map([.key, .value] | join(": ")) | .[]' "${2}" 2>/dev/null
}

# Read an array from yaml config file
# 1 - Path of key
# 2 - Path of yaml config file
# Returns array/map of values
function readConfigArray() {
  yq eval '.'${1}'[]' "${2}" 2>/dev/null
}

# Write to yaml config file
# 1 - Path of Key
# 2 - Value
# 3 - Path of yaml config file
function writeConfigKey() {
  [ "${2}" = "{}" ] && yq eval '.'${1}' = {}' --inplace "${3}" 2>/dev/null || yq eval '.'${1}' = "'"${2}"'"' --inplace "${3}" 2>/dev/null
}

# Return list of all modules available
# 1 - Platform
# 2 - Kernel Version
function getAllModules() {
  local PLATFORM=${1}
  local KVER=${2}

  if [ -z "${PLATFORM}" -o -z "${KVERP}" ]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  local KERNEL="$(readConfigKey "kernel" "${USER_CONFIG_FILE}")"
  if [ "${KERNEL}" = "custom" ]; then
    tar -zxf "${CKS_PATH}/modules-${PLATFORM}-${KVERP}.tgz" -C "${TMP_PATH}/modules"
  else
    tar -zxf "${MODULES_PATH}/${PLATFORM}-${KVERP}.tgz" -C "${TMP_PATH}/modules"
  fi
  # Get list of all modules
  for F in $(ls ${TMP_PATH}/modules/*.ko 2>/dev/null); do
    local X=$(basename ${F})
    local M=${X:0:-3}
    local DESC=$(modinfo ${F} 2>/dev/null | awk -F':' '/description:/{ print $2}' | awk '{sub(/^[ ]+/,""); print}')
    [ -z "${DESC}" ] && DESC="${X}"
    echo "${M} \"${DESC}\""
  done
  rm -rf "${TMP_PATH}/modules"
}

# SYNC menu.sh

# 1 - update.zip path
# 2 - progress file path
function updateARC() {
  local UPDATE_FILE="${1:-"/tmp/update.zip"}"
  local PROGRESS_FILE="${2:-"/tmp/arc_update_progress"}"

  echo '{"progress": "0", "progressmsg": "Update ARC ..."}' >"${PROGRESS_FILE}"
  if [ ! -f "${UPDATE_FILE}" ]; then
    echo '{"progress": "-1", "progressmsg": "Update file not found!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "10", "progressmsg": "Extracting update file ..."}' >"${PROGRESS_FILE}"
  rm -rf "${TMP_PATH}/update"
  mkdir -p "${TMP_PATH}/update"
  unzip -oq "${UPDATE_FILE}" -d "${TMP_PATH}/update"
  if [ $? -ne 0 ]; then
    echo '{"progress": "-2", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  # Check checksums
  echo '{"progress": "20", "progressmsg": "Check checksums ..."}' >"${PROGRESS_FILE}"
  (cd "${TMP_PATH}/update" && sha256sum --status -c sha256sum)
  if [ $? -ne 0 ]; then
    echo '{"progress": "-3", "progressmsg": "Checksum do not match!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  # Check conditions
  echo '{"progress": "30", "progressmsg": "Check conditions ..."}' >"${PROGRESS_FILE}"
  if [ -f "${TMP_PATH}/update/update-check.sh" ]; then
    cat "${TMP_PATH}/update/update-check.sh" | bash
    if [ $? -ne 0 ]; then
      echo '{"progress": "-4", "progressmsg": "Update check failed, The current version does not support upgrading to the latest version!"}' >"${PROGRESS_FILE}"
      return 1
    fi
  fi

  echo '{"progress": "40", "progressmsg": "Check disk space ..."}' >"${PROGRESS_FILE}"
  SIZENEW=0
  SIZEOLD=0
  while IFS=': ' read KEY VALUE; do
    if [ "${KEY: -1}" = "/" ]; then
      rm -Rf "${TMP_PATH}/update/${VALUE}"
      mkdir -p "${TMP_PATH}/update/${VALUE}"
      tar -zxf "${TMP_PATH}/update/$(basename "${KEY}").tgz" -C "${TMP_PATH}/update/${VALUE}"
      if [ $? -ne 0 ]; then
        echo '{"progress": "-5", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
        return 1
      fi
      rm "${TMP_PATH}/update/$(basename "${KEY}").tgz"
    else
      mkdir -p "${TMP_PATH}/update/$(dirname "${VALUE}")"
      mv -f "${TMP_PATH}/update/$(basename "${KEY}")" "${TMP_PATH}/update/${VALUE}"
    fi
    SIZENEW=$((${SIZENEW} + $(du -sm "${TMP_PATH}/update/${VALUE}" 2>/dev/null | awk '{print $1}')))
    SIZEOLD=$((${SIZEOLD} + $(du -sm "${VALUE}" 2>/dev/null | awk '{print $1}')))
  done < <(readConfigMap "replace" "${TMP_PATH}/update/update-list.yml")

  SIZESPL=$(df -m ${PART3_PATH} 2>/dev/null | awk 'NR==2 {print $4}')
  if [ ${SIZENEW:-0} -ge $((${SIZEOLD:-0} + ${SIZESPL:-0})) ]; then
    MSG="$(printf "Failed to install due to insufficient remaning disk space on local hard drive, consider reallocate your disk %s with at least %sM." "${PART3_PATH}" "$((${SIZENEW} - ${SIZEOLD} - ${SIZESPL}))")"
    echo '{"progress": "-6", "progressmsg": "'${MSG}'"}' >"${PROGRESS_FILE}"
    return 1
  fi
  if [ -f "${TMP_PATH}/update/update-list.yml" ]; then
    # Process update-list.yml
    echo '{"progress": "50", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
    while read F; do
      [ -f "${F}" ] && rm -f "${F}"
      [ -d "${F}" ] && rm -Rf "${F}"
    done < <(readConfigArray "remove" "${TMP_PATH}/update/update-list.yml")

    echo '{"progress": "60", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
    while IFS=': ' read KEY VALUE; do
      if [ "${KEY: -1}" = "/" ]; then
        rm -Rf "${VALUE}"
        mkdir -p "${VALUE}"
        cp -Rf "${TMP_PATH}/update/${VALUE}"/* "${VALUE}"
        if [ "$(realpath "${VALUE}")" = "$(realpath "${MODULES_PATH}")" ]; then
          if [ -n "${MODEL}" -a -n "${PRODUCTVER}" ]; then
            KVER="$(readConfigKey "platforms.${PLATFORM}.productvers.[${PRODUCTVER}].kver" "${WORK_PATH}/platforms.yml")"
            KPRE="$(readConfigKey "platforms.${PLATFORM}.productvers.[${PRODUCTVER}].kpre" "${WORK_PATH}/platforms.yml")"
            if [ -n "${PLATFORM}" -a -n "${KVERP}" ]; then
              writeConfigKey "modules" "{}" "${USER_CONFIG_FILE}"
              while read ID DESC; do
                writeConfigKey "modules.\"${ID}\"" "" "${USER_CONFIG_FILE}"
              done < <(getAllModules "${PLATFORM}" "${KVERP}")
            fi
          fi
        fi
      else
        mkdir -p "$(dirname "${VALUE}")"
        cp -f "${TMP_PATH}/update/${VALUE}" "${VALUE}"
      fi
    done < <(readConfigMap "replace" "${TMP_PATH}/update/update-list.yml")
    rm -rf "${TMP_PATH}/update"
    echo '{"progress": "90", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  fi
  touch ${PART1_PATH}/.build
  sync
  echo '{"progress": "100", "progressmsg": "Arc updated success!"}' >"${PROGRESS_FILE}"
  return 0
}

# 1 - update.zip path
# 2 - progress file path
function updateAddons() {
  local UPDATE_FILE="${1:-"/tmp/addons.zip"}"
  local PROGRESS_FILE="${2:-"/tmp/arc_update_progress"}"

  echo '{"progress": "0", "progressmsg": "Update Addons ..."}' >"${PROGRESS_FILE}"
  if [ ! -f "${UPDATE_FILE}" ]; then
    echo '{"progress": "-1", "progressmsg": "Update file not found!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "10", "progressmsg": "Extracting update file ..."}' >"${PROGRESS_FILE}"
  rm -rf "${TMP_PATH}/update"
  mkdir -p "${TMP_PATH}/update"
  unzip -oq "${UPDATE_FILE}" -d "${TMP_PATH}/update"
  if [ $? -ne 0 ]; then
    echo '{"progress": "-2", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
    return 1
  fi

  for PKG in $(ls ${TMP_PATH}/update/*.addon 2>/dev/null); do
    ADDON=$(basename ${PKG} .addon)
    rm -rf "${TMP_PATH}/update/${ADDON}"
    mkdir -p "${TMP_PATH}/update/${ADDON}"
    tar -xaf "${PKG}" -C "${TMP_PATH}/update/${ADDON}"
    if [ $? -ne 0 ]; then
      echo '{"progress": "-3", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
      return 1
    fi
    rm -f "${PKG}"
  done
  SIZENEW="$(du -sm "${TMP_PATH}/update" 2>/dev/null | awk '{print $1}')"
  SIZEOLD="$(du -sm "${ADDONS_PATH}" 2>/dev/null | awk '{print $1}')"
  SIZESPL=$(df -m "${ADDONS_PATH}" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ ${SIZENEW:-0} -ge $((${SIZEOLD:-0} + ${SIZESPL:-0})) ]; then
    MSG="$(printf "Failed to install due to insufficient remaning disk space on local hard drive, consider reallocate your disk %s with at least %sM." "$(dirname "${ADDONS_PATH}")" "$((${SIZENEW} - ${SIZEOLD} - ${SIZESPL}))")"
    echo '{"progress": "-3", "progressmsg": "'${MSG}'"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "20", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  rm -Rf "${ADDONS_PATH}/"*
  cp -Rf "${TMP_PATH}/update/"* "${ADDONS_PATH}/"
  rm -rf "${TMP_PATH}/update"
  echo '{"progress": "90", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  touch ${PART1_PATH}/.build
  sync
  echo '{"progress": "100", "progressmsg": "Addons updated success!"}' >"${PROGRESS_FILE}"
  return 0
}

# 1 - update.zip path
# 2 - progress file path
function updateModules() {
  local UPDATE_FILE="${1:-"/tmp/modules.zip"}"
  local PROGRESS_FILE="${2:-"/tmp/arc_update_progress"}"

  echo '{"progress": "0", "progressmsg": "Update Modules ..."}' >"${PROGRESS_FILE}"
  if [ ! -f "${UPDATE_FILE}" ]; then
    echo '{"progress": "-1", "progressmsg": "Update file not found!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "10", "progressmsg": "Extracting update file ..."}' >"${PROGRESS_FILE}"
  rm -rf "${TMP_PATH}/update"
  mkdir -p "${TMP_PATH}/update"
  unzip -oq "${UPDATE_FILE}" -d "${TMP_PATH}/update"
  if [ $? -ne 0 ]; then
    echo '{"progress": "-2", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
    return 1
  fi

  SIZENEW="$(du -sm "${TMP_PATH}/update" 2>/dev/null | awk '{print $1}')"
  SIZEOLD="$(du -sm "${MODULES_PATH}" 2>/dev/null | awk '{print $1}')"
  SIZESPL=$(df -m "${MODULES_PATH}" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ ${SIZENEW:-0} -ge $((${SIZEOLD:-0} + ${SIZESPL:-0})) ]; then
    MSG="$(printf "Failed to install due to insufficient remaning disk space on local hard drive, consider reallocate your disk %s with at least %sM." "$(dirname "${MODULES_PATH}")" "$((${SIZENEW} - ${SIZEOLD} - ${SIZESPL}))")"
    echo '{"progress": "-3", "progressmsg": "'${MSG}'"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "20", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  rm -rf "${MODULES_PATH}/"*
  cp -rf "${TMP_PATH}/update/"* "${MODULES_PATH}/"
  rm -rf "${TMP_PATH}/update"
  if [ $? -ne 0 ]; then
    echo '{"progress": "-2", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "30", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  if [ -n "${MODEL}" -a -n "${PRODUCTVER}" ]; then
    KVER="$(readConfigKey "platforms.${PLATFORM}.productvers.[${PRODUCTVER}].kver" "${WORK_PATH}/platforms.yml")"
    # Modify KVER for Epyc7002
    if [ "${PLATFORM}" == "epyc7002" ]; then
      KVERP="${PRODUCTVER}-${KVER}"
    else
      KVERP="${KVER}"
    fi
    if [ -n "${PLATFORM}" -a -n "${KVERP}" ]; then
      writeConfigKey "modules" "{}" "${USER_CONFIG_FILE}"
      while read ID DESC; do
        writeConfigKey "modules.\"${ID}\"" "" "${USER_CONFIG_FILE}"
      done < <(getAllModules "${PLATFORM}" "${KVERP}")
    fi
  fi
  echo '{"progress": "90", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  touch ${PART1_PATH}/.build
  sync
  echo '{"progress": "100", "progressmsg": "Modules updated success!"}' >"${PROGRESS_FILE}"
  return 0
}

# 1 - update.zip path
# 2 - progress file path
function updateLKMs() {
  local UPDATE_FILE="${1:-"/tmp/rp-lkms.zip"}"
  local PROGRESS_FILE="${2:-"/tmp/arc_update_progress"}"

  echo '{"progress": "0", "progressmsg": "Update LKMs ..."}' >"${PROGRESS_FILE}"
  if [ ! -f "${UPDATE_FILE}" ]; then
    echo '{"progress": "-1", "progressmsg": "Update file not found!"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "10", "progressmsg": "Extracting update file ..."}' >"${PROGRESS_FILE}"
  rm -rf "${TMP_PATH}/update"
  mkdir -p "${TMP_PATH}/update"
  unzip -oq "${UPDATE_FILE}" -d "${TMP_PATH}/update"
  if [ $? -ne 0 ]; then
    echo '{"progress": "-2", "progressmsg": "Update file unzip failed!"}' >"${PROGRESS_FILE}"
    return 1
  fi

  SIZENEW="$(du -sm "${TMP_PATH}/update" 2>/dev/null | awk '{print $1}')"
  SIZEOLD="$(du -sm "${LKMS_PATH}" 2>/dev/null | awk '{print $1}')"
  SIZESPL=$(df -m "${LKMS_PATH}" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ ${SIZENEW:-0} -ge $((${SIZEOLD:-0} + ${SIZESPL:-0})) ]; then
    MSG="$(printf "Failed to install due to insufficient remaning disk space on local hard drive, consider reallocate your disk %s with at least %sM." "$(dirname "${LKMS_PATH}")" "$((${SIZENEW} - ${SIZEOLD} - ${SIZESPL}))")"
    echo '{"progress": "-3", "progressmsg": "'${MSG}'"}' >"${PROGRESS_FILE}"
    return 1
  fi
  echo '{"progress": "20", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  rm -rf "${LKMS_PATH}/"*
  cp -rf "${TMP_PATH}/update/"* "${LKMS_PATH}/"
  rm -rf "${TMP_PATH}/update"
  echo '{"progress": "90", "progressmsg": "Process update ..."}' >"${PROGRESS_FILE}"
  touch ${PART1_PATH}/.build
  sync
  echo '{"progress": "100", "progressmsg": "LKMs updated success!"}' >"${PROGRESS_FILE}"
  return 0
}

WORK_PATH="/tmp/initrd/opt/arc"
PLATFORM="$(readConfigKey "platform" "${USER_CONFIG_FILE}")"
MODEL="$(readConfigKey "model" "${USER_CONFIG_FILE}")"
PRODUCTVER="$(readConfigKey "productver" "${USER_CONFIG_FILE}")"

$@
