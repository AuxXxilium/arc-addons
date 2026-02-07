#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> && Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

VOLUME=$(/usr/syno/bin/servicetool --get-available-volume | head -1)
if [ -z "${VOLUME}" ] || [ ! -d "${VOLUME}" ]; then
  echo "No available volume found."
  exit 0
fi

if [ "${1}" = "-r" ]; then
  for I in $(mount | grep "on /volume1/virtio" | cut -d' ' -f3); do
    echo "Unmounting ${I}"
    umount -f "${I}"
  done
  for I in virtio9p virtiofs; do
    if synoshare --get "${I}" &>/dev/null; then
      echo "Removing share ${I}"
      synoshare --del "TRUE" "${I}"
    fi
  done
else
  for V in $(LC_ALL=C printf '%s\n' /sys/bus/virtio/drivers/9pnet_virtio/virtio*/mount_tag | sort -V); do
    [ -e "${V}" ] || continue
    read -r TAG <"${V}"
    [ -z "${TAG}" ] && continue
    mount | grep -qw "^${TAG}" && continue

    SHARE_NAME="virtio9p"
    SHARE_DESC="virtio9p share"
    SHARE_PATH="${VOLUME}/${SHARE_NAME}"
    if ! synoshare --get "${SHARE_NAME}" &>/dev/null; then
      echo "Creating share ${SHARE_NAME} at ${SHARE_PATH}"
      synoshare --add "${SHARE_NAME}" "${SHARE_DESC}" "${SHARE_PATH}" "" "@user" "" 1 0
    fi
    if [ -d "${SHARE_PATH}" ]; then
      MOUNT_POINT="${SHARE_PATH}/${TAG}"
      mkdir -p "${MOUNT_POINT}"
      if ! mount | grep -qw "on ${MOUNT_POINT} "; then
        echo "Mounting ${TAG} to ${MOUNT_POINT}"
        mount -t 9p -o trans=virtio,version=9p2000.L "${TAG}" "${MOUNT_POINT}"
      fi
    fi
  done

  for V in $(LC_ALL=C printf '%s\n' /sys/bus/virtio/drivers/virtiofs/virtio*/tag | sort -V); do
    [ -e "${V}" ] || continue
    read -r TAG <"${V}"
    [ -z "${TAG}" ] && continue
    mount | grep -qw "^${TAG}" && continue

    SHARE_NAME="virtiofs"
    SHARE_DESC="virtiofs share"
    SHARE_PATH="${VOLUME}/${SHARE_NAME}"
    if ! synoshare --get "${SHARE_NAME}" &>/dev/null; then
      echo "Creating share ${SHARE_NAME} at ${SHARE_PATH}"
      synoshare --add "${SHARE_NAME}" "${SHARE_DESC}" "${SHARE_PATH}" "" "@user" "" 1 0
    fi
    if [ -d "${SHARE_PATH}" ]; then
      MOUNT_POINT="${SHARE_PATH}/${TAG}"
      mkdir -p "${MOUNT_POINT}"
      if ! mount | grep -qw "on ${MOUNT_POINT} "; then
        echo "Mounting ${TAG} to ${MOUNT_POINT}"
        mount -t virtiofs -o sync,dirsync "${TAG}" "${MOUNT_POINT}"
      fi
    fi
  done
fi
exit 0
