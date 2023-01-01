#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for NVMe Cache"
  tar -zxvf /addons/nvme.tgz -C /tmpRoot/
  chmod 755 /tmpRoot/usr/bin/nvme
  chmod 644 /tmpRoot/usr/lib/systemd/system/nvme.service
  ln -sf /usr/lib/systemd/system/nvme.service /tmpRoot/etc/systemd/system/multi-user.target.wants/nvme.service
fi
