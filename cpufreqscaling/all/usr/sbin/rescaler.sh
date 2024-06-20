#!/usr/bin/env bash

# Make things safer
set -euo pipefail

rm -f /usr/sbin/stopscale

systemctl enable cpufreqscaling.service
systemctl start cpufreqscaling.service

# Get cpu cores count minus 1, to allow maping from 0
cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
cpucorecount=$((cpucorecount - 1))
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

if [ -f "/usr/lib/modules/cpufreq_${1}" ] || [ "${1}" = "userspace" ]; then
  # Set correct cpufreq governor to allow user defined frequency scaling
  if [ "$governor" != "${1}" ]; then
    for i in $(seq 0 "${cpucorecount}"); do
      echo "${1}" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_governor
    done
  fi
else
  echo "No cpufreq_${1} module found"
  exit 1
fi
