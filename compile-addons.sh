#!/usr/bin/env bash

set -e

TMP_PATH="/tmp"
YQ_BIN="$(dirname $0)/yq"

###############################################################################
#
# 1 - Path of key
function hasConfigKey() {
  [ "$(${YQ_BIN} eval '.'${1}' | has("'${2}'")' "${3}")" == "true" ] && return 0 || return 1
}

###############################################################################
# Read key value from yaml config file
# 1 - Path of key
# 2 - Path of yaml config file
# Return Value
function readConfigKey() {
  RESULT=$(${YQ_BIN} eval '.'${1}' | explode(.)' "${2}")
  [ "${RESULT}" == "null" ] && echo "" || echo ${RESULT}
}

###############################################################################
# Read Entries as array from yaml config file
# 1 - Path of key
# 2 - Path of yaml config file
# Returns array of values
function readConfigEntriesArray() {
  ${YQ_BIN} eval '.'${1}' | explode(.) | to_entries | map([.key])[] | .[]' "${2}"
}

###############################################################################
function compile-addon() {
  # Read manifest file
  MANIFEST="${1}/manifest.yml"
  if [ ! -f "${MANIFEST}" ]; then
    echo -e "\033[1;44mWarning: ${MANIFEST} not found, ignoring it\033[0m"
    return 0
  fi
  echo -e "\033[7mProcessing manifest ${MANIFEST}\033[0m"
  OUT_PATH="${TMP_PATH}/${1}"
  rm -rf "${OUT_PATH}"
  mkdir -p "${OUT_PATH}"
  # Check if has compile script
  COMPILESCRIPT=$(readConfigKey "compile-script" "${MANIFEST}")
  if [ -n "${COMPILESCRIPT}" ]; then
    echo "Running compile script"
    pushd . >/dev/null
    cd "${1}"
    ./${COMPILESCRIPT}
    popd >/dev/null
  fi
  # Copy manifest to destiny
  cp "${MANIFEST}" "${OUT_PATH}"
  # Check if exist files for all platforms
  if hasConfigKey "" "all" "${MANIFEST}"; then
    echo -e "\033[1;32m Processing 'all' section\033[0m"
    HAS_FILES=0
    # Get name of script to install, if defined. This script has low priority
    INSTALL_SCRIPT="$(readConfigKey "all.install-script" "${MANIFEST}")"
    if [ -n "${INSTALL_SCRIPT}" ]; then
      if [ -f "${1}/${INSTALL_SCRIPT}" ]; then
        echo -e "\033[1;35m  Copying install script ${INSTALL_SCRIPT}\033[0m"
        mkdir -p "${OUT_PATH}/all"
        cp "${1}/${INSTALL_SCRIPT}" "${OUT_PATH}/all/install.sh"
        HAS_FILES=1
      else
        echo -e "\033[1;33m  WARNING: install script '${INSTALL_SCRIPT}' not found\033[0m"
      fi
    fi
    # Get folder name for copy
    COPY_PATH="$(readConfigKey "all.copy" "${MANIFEST}")"
    # If folder exists, copy
    if [ -n "${COPY_PATH}" ]; then
      if [ -d "${1}/${COPY_PATH}" ]; then
        echo -e "\033[1;35m  Copying folder '${COPY_PATH}'\033[0m"
        mkdir -p "${OUT_PATH}/all/root"
        cp -R "${1}/${COPY_PATH}/"* "${OUT_PATH}/all/root"
        HAS_FILES=1
      else
        echo -e "\033[1;33m  WARNING: folder '${COPY_PATH}' not found\033[0m"
      fi
    fi
    if [ ${HAS_FILES} -eq 1 ]; then
      # Create tar gziped
      tar -zcf "${OUT_PATH}/all.tgz" -C "${OUT_PATH}/all" .
      echo -e "\033[1;36m  Created file '${OUT_PATH}/all.tgz' \033[0m"
    fi
    # Clean
    rm -rf "${OUT_PATH}/all"
  fi

  # Create addon package
  tar -zcf "${1}.addon" -C "${OUT_PATH}" .
  rm -rf "${OUT_PATH}"
}

# Main
if [ $# -ge 1 ]; then
  for A in $@; do
    compile-addon ${A%/}
  done
else
  while read -r D; do
    DRIVER=$(basename ${D})
    [ "${DRIVER:0:1}" = "." ] && continue
    compile-addon ${DRIVER}
  done < <(find -maxdepth 1 -type d)
fi
wait