#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon ledcontrol - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  cp -vf /usr/bin/ledcontrol.sh /tmpRoot/usr/bin/ledcontrol.sh
  cp -vf /usr/bin/ugreen_leds_cli /tmpRoot/usr/bin/ugreen_leds_cli
  cp -vf /usr/arc/addons/led.conf /tmpRoot/usr/arc/addons/led.conf
  cp -vf /usr/lib/modules/i2c-i801.ko /tmpRoot/usr/lib/modules/i2c-i801.ko
  cp -vf /usr/lib/modules/i2c-smbus.ko /tmpRoot/usr/lib/modules/i2c-smbus.ko
  modprobe i2c-i801
  modprobe i2c-smbus

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
# NIC
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  cat > ${DEST} <<EOF
[Unit]
Description=NIC Ledcontrol for Ugreen
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=oneshot
Restart=no
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh nic

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol_disk.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_disk.service
# Disk
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.service"
  cat > ${DEST} <<EOF
[Unit]
Description=Disk Ledcontrol for Ugreen
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=onshot
Restart=no
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh disk

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol_disk.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_disk.service

  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.service"
  cat > ${DEST} <<EOF
[Unit]
Description=CPU Ledcontrol for Ugreen
DefaultDependencies=no
IgnoreOnIsolate=true
After=multi-user.target

[Service]
User=root
Type=oneshot
Restart=no
RemainAfterExit=yes
ExecStart=/usr/bin/ledcontrol.sh cpu

[Install]
WantedBy=multi-user.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol_cpu.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_cpu.service
# Timer for Disk
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.timer"
  cat > ${DEST} <<EOF
[Unit]
Description=Disk Ledcontrol Timer for Ugreen

[Timer]
OnBootSec=5m
OnUnitInactiveSec=5m
Persistent=true
User=root
Unit=ledcontrol_disk.service

[Install]
WantedBy=timers.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/timers.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol_disk.timer /tmpRoot/usr/lib/systemd/system/timers.target.wants/ledcontrol_disk.timer
# Timer for CPU
  DEST="/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.timer"
  cat > ${DEST} <<EOF
[Unit]
Description=CPU Ledcontrol Timer for Ugreen

[Timer]
OnBootSec=5s
OnUnitInactiveSec=0.2s
Persistent=true
User=root
Unit=ledcontrol_cpu.service

[Install]
WantedBy=timers.target
EOF
  mkdir -vp /tmpRoot/usr/lib/systemd/system/timers.target.wants
  ln -vsf /usr/lib/systemd/system/ledcontrol_cpu.timer /tmpRoot/usr/lib/systemd/system/timers.target.wants/ledcontrol_cpu.timer
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon ledcontrol - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/ledcontrol_cpu.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/timers.target.wants/ledcontrol_disk.timer"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_disk.timer"
  rm -f "/tmpRoot/usr/lib/systemd/system/timers.target.wants/ledcontrol_cpu.timer"
  rm -f "/tmpRoot/usr/lib/systemd/system/ledcontrol_cpu.timer"

  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/ledcontrol.sh" >>/tmpRoot/usr/arc/revert.sh
fi