#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/007revad/Synology_HDD_db
#
# hdddb.sh patches the drive databases, then diskcompat.sh (once its own
# addon) patches DSM's runtime state for each drive, which synostoraged has
# already evaluated against the unpatched databases by then.
#
# No -I: hdddb.sh asks before downloading dhm_tool, and a service has no
# terminal to ask on, so it only ever failed here. Arc Control can still run
# hdddb with it.

if [ "${1}" = "late" ]; then
  echo "Installing addon hdddb - ${1}"

  # Create necessary directories and copy files
  mkdir -p "/tmpRoot/usr/arc/addons/" "/tmpRoot/usr/bin/" "/tmpRoot/usr/sbin/" "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -pf /usr/bin/hdddb.sh /tmpRoot/usr/bin/hdddb.sh
  cp -pf /usr/bin/diskcompat.sh /tmpRoot/usr/bin/diskcompat.sh

  # diskcompat's own unit, from before it was merged in here.
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/diskcompat.service" \
        "/tmpRoot/usr/lib/systemd/system/diskcompat.service"

  # After SynoOnlinePack: on a first boot DSM installs it while the boot goes
  # on, and it writes every db in /var/lib/disk-compatibility anew - ours
  # included, half a minute after hdddb.sh patched them - and the disks are
  # evaluated against the stock ones again. Not After StorageManager: that
  # puts hdddb after syno-space.target, and nothing here needs it.
  #
  # ExecStart keeps its "-", as Arc Control writes it: diskcompat.sh is most
  # needed when hdddb.sh failed. Arc Control rewrites every ExecStart= line
  # with its own flags, so diskcompat.sh is ExecStartPost=, not a second one.
  cat <<EOF >"/tmpRoot/usr/lib/systemd/system/hdddb.service"
[Unit]
Description=HDDs/SSDs drives databases
Wants=smpkg-custom-install.service pkgctl-StorageManager.service
After=smpkg-custom-install.service pkgctl-SynoOnlinePack.service pkgctl-SynoOnlinePack_v2.service pkgctl-SynoOnlinePack_v3.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/usr/sbin/modprobe sg
ExecStartPre=-/usr/bin/disks.sh --wait
ExecStart=-/usr/bin/hdddb.sh -nrwpe
ExecStartPost=-/usr/bin/diskcompat.sh
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

  ln -vsf /usr/lib/systemd/system/hdddb.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service
elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon hdddb - ${1}"

  # Remove systemd files
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/hdddb.service" \
        "/tmpRoot/usr/lib/systemd/system/hdddb.service"

  # Create revert script if not present
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && {
    echo '#!/usr/bin/env bash' > /tmpRoot/usr/arc/revert.sh
    chmod +x /tmpRoot/usr/arc/revert.sh
  }

  # Add revert commands
  echo "/usr/bin/hdddb.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/hdddb.sh" >> /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/diskcompat.sh --restore" >> /tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/diskcompat.sh" >> /tmpRoot/usr/arc/revert.sh
fi
