#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "late" ]; then
  echo "Installing addon vmtools - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/usr/vmtools
  tar -zxf /addons/vmtools-7.1.tgz -C /tmpRoot/usr/vmtools

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/vmtools.service"
  if grep -Eq 'mev=vmware' /proc/cmdline; then

    VMTOOLS_PATH="/usr/vmtools"
    COMMON_PATH=${VMTOOLS_PATH}/lib/open-vm-tools/plugins
    PLUGINS_PATH=${COMMON_PATH}/vmsvc

    VMWARE_CONF="/usr/vmtools/etc/vmware-tools/tools.conf"
    mkdir -p /tmpRoot/usr/vmtools/etc/vmware-tools
    {
      echo "[vmtools]"
      echo "     disable-tools-version = false"
      echo "[setenvironment]"
      echo "    vmsvc.LOCALE = us"
      echo "[logging]"
      echo "    log = true"
      echo "    vmsvc.level = debug"
      echo "    vmsvc.handler = file"
      echo "    vmsvc.data = /var/log/vmsvc.arc.log"
      echo "    vmtoolsd.level = debug"
      echo "    vmtoolsd.handler = file"
      echo "    vmtoolsd.data = /var/log/vmtoolsd.arc.log"
      echo "[powerops]"
      echo "    poweron-script=${VMTOOLS_PATH}/etc/vmware-tools/poweron-vm-default"
      echo "    poweroff-script=${VMTOOLS_PATH}/etc/vmware-tools/poweroff-vm-default"
      echo "    resume-script=${VMTOOLS_PATH}/etc/vmware-tools/resume-vm-default"
      echo "    suspend-script=${VMTOOLS_PATH}/etc/vmware-tools/suspend-vm-default"
    } >"/tmpRoot${VMWARE_CONF}"

    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Environment=\"PATH=/usr/vmtools/bin:/usr/vmtools/sbin:\$PATH\""
      echo "Environment=\"LD_LIBRARY_PATH=/usr/vmtools/lib:\$LD_LIBRARY_PATH\""
      echo "ExecStart=/usr/vmtools/bin/vmtoolsd -c ${VMWARE_CONF} --common-path=${COMMON_PATH} --plugin-path=${PLUGINS_PATH} -b /var/run/vmtools.pid"
      echo "Restart=always"
      echo "RestartSec=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"
  elif grep -Eq 'mev=kvm|mev=qemu' /proc/cmdline; then
    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo "ConditionPathExists=/dev/virtio-ports/org.qemu.guest_agent.0"
      echo
      echo "[Service]"
      echo "Environment=\"PATH=/usr/vmtools/bin:/usr/vmtools/sbin:$$PATH\""
      echo "Environment=\"LD_LIBRARY_PATH=/usr/vmtools/lib:$$LD_LIBRARY_PATH\""
      echo "ExecStart=/usr/vmtools/bin/qemu-ga -m virtio-serial -p /dev/virtio-ports/org.qemu.guest_agent.0 -t /var/run/ -f /var/run/vmtools.pid"
      echo "Restart=always"
      echo "RestartSec=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"
  else
    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Environment=\"PATH=/usr/vmtools/bin:/usr/vmtools/sbin:$$PATH\""
      echo "Environment=\"LD_LIBRARY_PATH=/usr/vmtools/lib:$$LD_LIBRARY_PATH\""
      echo "ExecStart=-echo Unknown mev"
      echo "Type=oneshot"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"
    exit 1
  fi
  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/vmtools.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon vmtools - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/vmtools.service"

  rm -rf /tmpRoot/usr/vmtools
fi