#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for Synocode Patch"
  tar -zxvf /addons/nvme.tgz -C /tmpRoot/
  chmod 755 /tmpRoot/usr/bin/synocode
  chmod 644 /tmpRoot/usr/lib/systemd/system/synocode.service
  ln -sf /usr/lib/systemd/system/synocode.service /tmpRoot/etc/systemd/system/multi-user.target.wants/synocode.service
fi
