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

# Each script runs once at most. It is moved out of once.d into once.run
# and the move synced before it runs, so one that fails, hangs, or is
# cut off by a shutdown is not run again at the next start. once.run is
# beside once.d on DSM's own disk, not in /tmp, which DSM mounts noexec:
# the move is a rename, and a script without .sh can still be executed.
# What once.run still holds at a start was begun by the one before it,
# and is removed unrun. One that cannot be moved is not run at all.
RUN="/usr/arc/once.run"
rm -rf "${RUN}" 2>/dev/null
mkdir -p "${RUN}" 2>/dev/null
for F in $(LC_ALL=C printf '%s\n' /usr/arc/once.d/* | sort -V); do
  [ ! -e "${F}" ] && continue
  mv -f "${F}" "${RUN}/" 2>/dev/null || continue
  sync
  R="${RUN}/$(basename "${F}")"
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
  rm -f "${R}"
done

# Whatever is left in once.d could not be moved: it is removed unrun.
rm -rf "${RUN}" 2>/dev/null
rm -f /usr/arc/once.d/* 2>/dev/null