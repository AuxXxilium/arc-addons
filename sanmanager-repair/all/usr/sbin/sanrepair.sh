#!/usr/bin/env bash

# Make things safer
set -euo pipefail

if [ $(synopkg status ScsiTarget | grep error | wc -l) -gt 0 ]; then

    modprobe target_core_mod
    modprobe target_core_iblock
    modprobe target_core_file
    modprobe target_core_multi_file
    modprobe target_core_user
    modprobe iscsi_target_mod
    modprobe tcm_loop
    modprobe vhost
    modprobe vhost_scsi

    synopkg start ScsiTarget
    
fi

if [ -d /config/target ]; then
    mkdir /config/target/iscsi
    mkdir /config/target/loopback
fi