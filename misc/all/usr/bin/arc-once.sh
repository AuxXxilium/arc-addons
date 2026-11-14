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

for F in $(LC_ALL=C printf '%s\n' /usr/arc/once.d/* | sort -V); do
  [ ! -e "${F}" ] && continue
  case "${F}" in
  *.sh)
    (
      trap - INT QUIT TSTP
      set start
      # shellcheck source=/usr/arc/once.d/*
      . "${F}"
    )
    ;;
  *)
    # No sh extension, so fork subprocess.
    chmod +x "${F}" 2>/dev/null
    "${F}" start
    ;;
  esac
done

rm -f /usr/arc/once.d/* 2>/dev/null