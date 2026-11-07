#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Runs powersched at the start of every minute, as its crontab line did. From
# one process rather than cron: a crond that logs each job writes to
# /var/log, on DSM's system partition - a RAID 1 across every data disk - so
# a run a minute was a write a minute, and no disk could stay asleep. Its
# output goes nowhere for the same reason.

while true; do
  /usr/sbin/powersched >/dev/null 2>&1
  S="$(date +%S)"
  S="${S#0}"
  sleep $((60 - ${S:-0}))
done
