#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
echo "insert RebootToArc task"
/tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
INSERT INTO task VALUES('RebootToArc', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/arc-reboot.sh "config"', 'script', '{}', '', '', '{}', '{}');
EOF
else
echo "copy RebootToArc task db"
mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
cp -f /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
fi
fi