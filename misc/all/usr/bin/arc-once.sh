#!/usr/bin/env bash
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# The loader's once.d scripts (Reset Password, Add DSM User, Force DSM
# SSH) call synouser, synogroup and synowebapi by name. A systemd unit
# does not get a login shell's PATH, and those live in /usr/syno, so it
# is added -- last, so nothing on the PATH already is shadowed.
export PATH="${PATH:-/usr/sbin:/usr/bin:/sbin:/bin}:/usr/syno/sbin:/usr/syno/bin"

# Each script runs once at most. It is moved off DSM's disk to /tmp and
# the removal synced before it runs, so one that fails, hangs, or is cut
# off by a shutdown is not run again at the next start. One that cannot
# be moved is not run at all.
for F in $(LC_ALL=C printf '%s\n' /usr/arc/once.d/* | sort -V); do
  [ ! -e "${F}" ] && continue
  D="$(mktemp -d /tmp/arc-once.XXXXXX)" || continue
  if ! mv -f "${F}" "${D}/" 2>/dev/null; then
    rm -rf "${D}"
    continue
  fi
  sync
  R="${D}/$(basename "${F}")"
  case "${R}" in
  *.sh)
    (
      trap - INT QUIT TSTP
      set start
      # shellcheck source=/usr/arc/once.d/*
      . "${R}"
    )
    ;;
  *)
    # No sh extension, so fork subprocess.
    chmod +x "${R}" 2>/dev/null
    "${R}" start
    ;;
  esac
  rm -rf "${D}"
done

# Whatever is left could not be moved: it is removed unrun.
rm -f /usr/arc/once.d/* 2>/dev/null