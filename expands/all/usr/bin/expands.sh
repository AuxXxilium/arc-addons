#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Both files are fetched with their certificate checked, https only, into a
# private temporary directory, and put in place only when they look like what
# they are. Until now curl ran with -k and wrote to fixed names in /tmp: the CA
# bundle became DSM's trust store from whoever answered, so one forged answer
# could add a root that every later certificate check on the NAS trusts.
CURL_OPTS=(-fsSL --proto '=https' --proto-redir '=https' --connect-timeout 15 -m 120)
WORK="$(mktemp -d 2>/dev/null)" || { echo "no temporary directory"; exit 1; }
trap 'rm -rf "${WORK}"' EXIT

if [ "${1}" = "-r" ]; then
  # usb.map
  FILE="/usr/syno/etc/usb.map"
  /usr/bin/arc-backup.sh restore "${FILE}"

  # ca-certificates.crt
  FILE="/etc/ssl/certs/ca-certificates.crt"
  /usr/bin/arc-backup.sh restore "${FILE}"
else
  # usb.map, from the usb.ids repository: www.linux-usb.org serves it over
  # plain http only (its certificate is for another name).
  FILE="/usr/syno/etc/usb.map"
  if [ -f "${FILE}" ]; then
    if ! curl "${CURL_OPTS[@]}" "https://raw.githubusercontent.com/usbids/usbids/master/usb.ids" -o "${WORK}/usb.map"; then
      echo "usb.ids download error!"
    elif ! head -c 4096 "${WORK}/usb.map" | grep -q "List of USB ID's" || [ "$(stat -c%s "${WORK}/usb.map")" -lt 100000 ]; then
      echo "usb.ids download is not a usb.ids file, not used!"
    else
      /usr/bin/arc-backup.sh take "${FILE}"
      cp -vpf "${WORK}/usb.map" "${FILE}"
      /usr/bin/arc-backup.sh seal "${FILE}"
    fi
  fi

  # ca-certificates.crt, curl's extract of Mozilla's bundle, checked against
  # the SHA-256 curl.se publishes for it and for being a bundle at all.
  FILE="/etc/ssl/certs/ca-certificates.crt"
  if [ -f "${FILE}" ]; then
    if ! curl "${CURL_OPTS[@]}" "https://curl.se/ca/cacert.pem" -o "${WORK}/cacert.pem" ||
      ! curl "${CURL_OPTS[@]}" "https://curl.se/ca/cacert.pem.sha256" -o "${WORK}/cacert.pem.sha256"; then
      echo "ca-certificates.crt download error!"
    elif [ "$(awk '{print tolower($1); exit}' "${WORK}/cacert.pem.sha256")" != "$(sha256sum "${WORK}/cacert.pem" | awk '{print $1}')" ]; then
      echo "ca-certificates.crt does not match its published checksum, not used!"
    elif [ "$(grep -c -- '-----BEGIN CERTIFICATE-----' "${WORK}/cacert.pem")" -lt 100 ]; then
      echo "ca-certificates.crt download is not a CA bundle, not used!"
    else
      /usr/bin/arc-backup.sh take "${FILE}"
      cp -vpf "${WORK}/cacert.pem" "${FILE}"
      /usr/bin/arc-backup.sh seal "${FILE}"
    fi
  fi
fi

exit 0
