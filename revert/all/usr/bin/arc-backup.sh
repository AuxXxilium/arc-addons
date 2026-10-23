#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# The backups addons keep of the DSM files they patch, each tied to the DSM
# build and model it was taken on. A DSM update or a model change ships that
# release's own copy of a file, and a backup from before it is another
# release's: copied back - on uninstall, or on every boot where an addon
# rebuilds its patch from the backup - it puts an old binary or config into
# the new DSM, which can break it.
#
#   arc-backup.sh check FILE [BAK]    whether BAK is still DSM's copy of FILE
#   arc-backup.sh take FILE [BAK]     make it so, backing FILE up again if not
#   arc-backup.sh seal FILE           note FILE as the addons left it
#   arc-backup.sh restore FILE [BAK]  put BAK back over FILE, if still DSM's
#
# BAK defaults to FILE.bak, and its build and model are kept in BAK.dsm. A
# FILE under /tmpRoot is read against that DSM, for the loader's late stage.
#
# Across an update or a model change a backup stays valid only while FILE is
# still what the addons left last time - its seal: that release did not ship
# FILE, so the backup is still its copy. Otherwise FILE is the new release's
# own: take backs it up afresh, and restore drops the old backup rather than
# putting it back. seal covers every backup of FILE, as more than one addon
# can patch the same file. A backup from before this has no build to go by
# and is taken to be the current one's.

ACTION="${1}"
FILE="${2}"
BAK="${3:-${FILE}.bak}"
TAG="${BAK}.dsm"

ROOT=""
case "${FILE}" in /tmpRoot/*) ROOT="/tmpRoot" ;; esac
VER="${ROOT}/etc.defaults/VERSION"
BUILD="$(/bin/get_key_value "${VER}" buildnumber 2>/dev/null)"
# Unreadable, there is no build to compare, and nothing counts as changed.
DSM=""
[ -n "${BUILD}" ] && DSM="${BUILD}-$(/bin/get_key_value "${VER}" smallfixnumber 2>/dev/null)-$(/bin/get_key_value "${VER}" nano 2>/dev/null) $(cat /proc/sys/kernel/syno_hw_version 2>/dev/null)"
# A package's file (Storage Manager's, from DSM 7.3) is shipped again by a
# package update as well, without DSM's build changing.
case "${FILE#"${ROOT}"}" in
/usr/local/packages/@appstore/*/*)
  PKG="${FILE#"${ROOT}"/usr/local/packages/@appstore/}"
  PKG="${PKG%%/*}"
  [ -n "${DSM}" ] && DSM="${DSM} ${PKG}-$(/bin/get_key_value "${ROOT}/var/packages/${PKG}/INFO" version 2>/dev/null)"
  ;;
esac

_sum() { md5sum "${1}" 2>/dev/null | cut -d' ' -f1; }
_line() { sed -n "${1}p" "${TAG}" 2>/dev/null; }

_valid() {
  [ -f "${BAK}" ] || return 1
  [ -f "${TAG}" ] || return 0
  [ -z "${DSM}" ] && return 0
  [ "$(_line 1)" = "${DSM}" ] && return 0
  [ -f "${FILE}" ] && [ -n "$(_line 2)" ] && [ "$(_sum "${FILE}")" = "$(_line 2)" ]
}

case "${ACTION}" in
check)
  _valid
  ;;
take)
  if _valid; then
    # This build, or one that did not ship FILE: the seal carries over.
    [ -n "${DSM}" ] && [ "$(_line 1)" != "${DSM}" ] && printf '%s\n%s\n' "${DSM}" "$(_line 2)" >"${TAG}"
    exit 0
  fi
  if [ ! -f "${FILE}" ]; then
    # Nothing to back up, and an addon that rebuilds from the backup would
    # otherwise put the old release's copy back in its place.
    [ -f "${BAK}" ] && echo "arc-backup: ${BAK} is from DSM $(_line 1), not ${DSM}, and ${FILE} is gone - removing it"
    rm -f "${BAK}" "${TAG}"
    exit 1
  fi
  [ -f "${BAK}" ] && echo "arc-backup: ${BAK} is from DSM $(_line 1), not ${DSM} - backing up ${FILE} again"
  cp -pf "${FILE}" "${BAK}" && printf '%s\n\n' "${DSM}" >"${TAG}"
  ;;
seal)
  [ -f "${FILE}" ] || exit 0
  SUM="$(_sum "${FILE}")"
  for T in "${FILE}".bak*.dsm; do
    [ -f "${T}" ] || continue
    printf '%s\n%s\n' "$(sed -n 1p "${T}")" "${SUM}" >"${T}"
  done
  ;;
restore)
  if _valid; then
    mv -f "${BAK}" "${FILE}"
  elif [ -f "${BAK}" ]; then
    echo "arc-backup: not restoring ${BAK} - it is from DSM $(_line 1), and ${FILE} is ${DSM}'s own"
    rm -f "${BAK}"
  fi
  rm -f "${TAG}"
  ;;
*)
  echo "Usage: ${0} check|take|restore FILE [BAK] | seal FILE" >&2
  exit 2
  ;;
esac
