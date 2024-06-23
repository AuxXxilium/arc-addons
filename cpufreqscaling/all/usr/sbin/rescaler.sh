#!/usr/bin/env bash

# Make things safer
set -euo pipefail

if [ -f /usr/sbin/stopscale ]; then
    rm -f /usr/sbin/stopscale
fi

# Get cpu cores count minus 1, to allow maping from 0
cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
cpucorecount=$((cpucorecount - 1))
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

# Set correct cpufreq governor to allow user defined frequency scaling
if [ "${1}" == "ondemand" ] || [ "${1}" == "conservative" ]; then
  if [ -f "/usr/lib/modules/cpufreq_${1}.ko" ]; then
    modprobe cpufreq_${1}
    if [ "$governor" != "${1}" ]; then
    for i in $(seq 0 "${cpucorecount}"); do
      echo "${1}" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_governor
    done
  fi
  else
    echo "No cpufreq_${1} module found"
    exit 1
  fi
else
  if [ "$governor" != "${1}" ]; then
    for i in $(seq 0 "${cpucorecount}"); do
      echo "${1}" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_governor
    done
  fi
fi

governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "$governor" != "${1}" ]; then
  systemctl restart cpufreqscaling.service
fi