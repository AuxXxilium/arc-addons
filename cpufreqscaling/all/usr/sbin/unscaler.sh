#!/usr/bin/env bash

# Make things safer
set -euo pipefail

systemctl stop cpufreq-userspace-scaler.service
systemctl disable cpufreq-userspace-scaler.service

# Get cpu cores count minus 1, to allow maping from 0
cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
cpucorecount=$((cpucorecount - 1))
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

# Set correct cpufreq governor to allow user defined frequency scaling
if [ "$governor" != "performance" ]; then
  for i in $(seq 0 "${cpucorecount}"); do
    echo "performance" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_governor
  done
fi

touch /usr/sbin/stopscale
