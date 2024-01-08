#!/usr/bin/env ash
for disk in $(/usr/syno/bin/synodiskport -installable_disk_list); do
    dev=$(/usr/syno/bin/synodiskport -part_name_get 1 "${disk}")
    mdadm --manage /dev/md0 --add "/dev/${dev}"
done
while true; do
    sleep 1
    [ "$(cat /sys/block/md0/md/sync_action)" == "recover" ] || break
done
