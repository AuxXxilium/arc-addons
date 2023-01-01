#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for CPU Info"
  tar -zxvf /addons/cpuinfo.tgz -C /tmpRoot/
  chmod 755 /tmpRoot/usr/bin/cpuinfo
  chmod 644 /tmpRoot/usr/lib/systemd/system/cpuinfo.service
  ln -sf /usr/lib/systemd/system/cpuinfo.service /tmpRoot/etc/systemd/system/multi-user.target.wants/cpuinfo.service
fi
