#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

_process_patch() {
  local PATCH_FILE
  local BASE_DIR
  local TARGET_FILE
  local BACKUP_FILE
  local HEX_FILE

  PATCH_FILE="$1"
  BASE_DIR="$2"
  TARGET_FILE=""
  BACKUP_FILE=""
  HEX_FILE=""

  while IFS= read -r LINE; do
      case "$LINE" in
      "--- "*)
          # Finalize the previous file if necessary
          if [[ -n "$BACKUP_FILE" && -n "$HEX_FILE" ]]; then
              xxd -r "$HEX_FILE" "$TARGET_FILE"
              echo "Patch applied successfully to $TARGET_FILE"
              rm -f "$HEX_FILE"
          fi

          # Extract target file path
          ORIGINAL_FILE=$(echo "$LINE" | cut -d' ' -f2)
          TARGET_FILE="$BASE_DIR/$ORIGINAL_FILE"
          BACKUP_FILE="${TARGET_FILE}.bak"
          echo "Patching file: $TARGET_FILE"

          if [[ ! -f "$TARGET_FILE" ]]; then
              echo "Error: Target file $TARGET_FILE does not exist."
              continue
          fi

          mv "$TARGET_FILE" "$BACKUP_FILE"
          HEX_FILE=$(mktemp)
          xxd -g1 -c16 "$BACKUP_FILE" | cut -d' ' -f1-17 > "$HEX_FILE"
          ;;
      "@"*)
          # Parse patch line
          OFFSET=$(echo "$LINE" | cut -d':' -f1 | sed 's/@//')
          ORIGINAL_BYTES=$(echo "$LINE" | cut -d':' -f2 | cut -d'>' -f1 | xargs)
          MODIFIED_BYTES=$(echo "$LINE" | cut -d'>' -f2 | xargs)

          CURRENT_BYTES=$(grep "^$OFFSET:" "$HEX_FILE" | cut -d' ' -f2- | xargs)

          if [[ "$CURRENT_BYTES" != "$ORIGINAL_BYTES" ]]; then
              echo "Error: Bytes mismatch at offset $OFFSET in $BACKUP_FILE (Expected: $ORIGINAL_BYTES, Found: $CURRENT_BYTES)"
              rm -f "$HEX_FILE"
              continue
          fi

          sed -i "s/^$OFFSET:.*/$OFFSET: $MODIFIED_BYTES/" "$HEX_FILE"
          ;;
      "+++"*)
          # Skip redundant lines
          continue
          ;;
      esac
  done < "$PATCH_FILE"

  # Finalize the last file being processed
  if [[ -n "$BACKUP_FILE" && -n "$HEX_FILE" ]]; then
      xxd -r "$HEX_FILE" "$TARGET_FILE"
      echo "Patch applied successfully to $TARGET_FILE"
      rm -f "$HEX_FILE"
  fi
}

SSPATH="/var/packages/SurveillanceStation/target"
SSPATCHPATH="/usr/arc/addons/sspatch"
SVERSION=$(grep -oP '(?<=version=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')

if [[ -z "$SVERSION" ]]; then
  echo "sspatch: Please install Surveillance Station first"
else
  SUFFIX=""
  case "$(grep -oP '(?<=model=").*(?=")' /var/packages/SurveillanceStation/INFO | head -n1)" in
  "synology_denverton_dva3219") SUFFIX="_DVA_3219" ;;
  "synology_denverton_dva3221") SUFFIX="_DVA_3221" ;;
  "synology_geminilake_dva1622") SUFFIX="_openvino" ;;
  esac

  SSVERSION="${SVERSION}${SUFFIX}"

  if [[ -f "${SSPATCHPATH}/${SSVERSION}.patch" ]]; then
    echo "sspatch: Patch for ${SSVERSION} found"
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")
    for ENTRY in "${ENTRIES[@]}"; do
      for HOSTS_FILE in "/etc/hosts" "/etc.defaults/hosts"; do
        if [[ -f "$HOSTS_FILE" ]]; then
          if grep -Fxq "$ENTRY" "$HOSTS_FILE"; then
            echo "sspatch: Entry $ENTRY already exists in $HOSTS_FILE"
          else
            echo "sspatch: Adding entry $ENTRY to $HOSTS_FILE"
            echo "$ENTRY" | tee -a "$HOSTS_FILE"
          fi
        fi
      done
    done

    synopkg stop SurveillanceStation > /dev/null 2>&1 || true
    _process_patch "${SSPATCHPATH}/${SSVERSION}.patch" "$SSPATH"
    synopkg restart SurveillanceStation > /dev/null 2>&1 || true
  else
    echo "sspatch: Patch for ${SSVERSION} not found, skipping"
  fi
fi

exit 0