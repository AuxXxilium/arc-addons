#!/usr/bin/env ash

if [[ ${1} = late ]]; then
echo "delete all addon files"

# AME
rm -f /usr/sbin/amepatch.sh
rm -f /usr/lib/libsynoame-license.so
rm -f /lib/systemd/system/amepatch.service
rm -f /lib/systemd/system/multi-user.target.wants/amepatch.service
rm -f /tmpRoot/usr/sbin/amepatch.sh
rm -f /tmpRoot/usr/lib/libsynoame-license.so
rm -f /tmpRoot/lib/systemd/system/amepatch.service
rm -f /tmpRoot/lib/systemd/system/multi-user.target.wants/amepatch.service

# Codecpatch
rm -f /usr/sbin/codecpatch.sh
rm -f /usr/lib/systemd/system/codecpatch.service
rm -f /lib/systemd/system/multi-user.target.wants/codecpatch.service
rm -f /tmpRoot/usr/sbin/codecpatch.sh
rm -f /tmpRoot/usr/lib/systemd/system/codecpatch.service
rm -f /tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service
rm -f /lib/systemd/system/codecpatch.service
rm -f /lib/systemd/system/multi-user.target.wants/codecpatch.service
rm -f /tmpRoot/lib/systemd/system/codecpatch.service
rm -f /tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service

# CPU Info
rm -f /usr/sbin/cpuinfo.sh
rm -f /tmpRoot/usr/sbin/cpuinfo.sh
rm -f /tmpRoot/lib/systemd/system/cpuinfo.service
rm -f /lib/systemd/system/cpuinfo.service

# DiskDBPatch
rm -f /usr/sbin/diskdbpatch.sh
rm -f /tmpRoot/usr/sbin/diskdbpatch.sh
rm -f /tmpRoot/lib/systemd/system/diskdbpatch.service
rm -f /lib/systemd/system/diskdbpatch.service

# LSI Util
rm -f /usr/sbin/lsiutil
rm -f /tmpRoot/usr/sbin/lsiutil

# Powersched
rm -f /tmpRoot/usr/sbin/powersched
rm -f /usr/sbin/powersched

# Surveillance
rm -f /tmpRoot/usr/sbin/surveillancepatch.sh
rm -f /usr/sbin/surveillancepatch.sh
rm -f /usr/lib/libssutils.so
rm -f /tmpRoot/usr/lib/libssutils.so
rm -f /usr/lib/license.sh
rm -f /tmpRoot/usr/lib/license.sh
rm -f /usr/lib/S82surveillance.sh
rm -f /tmpRoot/usr/lib/S82surveillance.sh

# WOL
rm -f /tmpRoot/usr/sbin/ethtool
rm -f /usr/sbin/ethtool
rm -f /tmpRoot/lib/systemd/system/ethtool.service
rm -f /lib/systemd/system/ethtool.service

fi
