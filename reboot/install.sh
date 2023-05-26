#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
    if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
        echo "insert RebootToArc task"
        /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db "INSERT INFO task VALUES ('RebootToArc', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/arpl-reboot.sh "config"', 'script', '{}', '', '', '{}', '{}')"
    else
        echo "copy RebootToArc task db"
        mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
        cp -vf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
    fi
fi
