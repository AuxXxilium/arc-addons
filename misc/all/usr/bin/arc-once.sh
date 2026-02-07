#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

for F in $(LC_ALL=C printf '%s\n' /usr/rr/once.d/* | sort -V); do
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