#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
if [ -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
echo "insert RebootToArpl task"
/tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
INSERT INTO task VALUES('RebootToArpl', '', 'shutdown', '', 0, 0, 0, 0, '', 0, '/usr/bin/arpl-reboot.sh "config"', 'script', '{}', '', '', '{}', '{}');
EOF
else
echo "copy RebootToArpl task db"
mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
cp -f /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
fi
fi