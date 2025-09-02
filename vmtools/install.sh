#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
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
  ln -vsf /usr/vmtools/etc/open-vm-tools /tmpRoot/etc/open-vm-tools
  ln -vsf /usr/vmtools/lib/open-vm-tools /tmpRoot/lib/open-vm-tools
  ln -vsf /usr/vmtools/share/open-vm-tools /tmpRoot/share/open-vm-tools

  VMTOOLS_PATH="/usr/vmtools"
  VMTOOLS_PID="/var/run/vmtools.pid"

  mkdir -p "/tmpRoot/usr/lib/systemd/system"

  if grep -Eq 'mev=vmware' /proc/cmdline; then
    VMWARE_CONF="${VMTOOLS_PATH}/etc/vmware-tools/tools.conf"
    COMMON_PATH="${VMTOOLS_PATH}/lib/open-vm-tools/plugins"
    PLUGINS_PATH="${COMMON_PATH}/vmsvc"

    mkdir -p /tmpRoot/usr/vmtools/etc/vmware-tools
    {
      echo "[vmtools]"
      echo "    disable-tools-version = false"
      echo "[logging]"
      echo "    log = true"
      echo "    vmsvc.level = debug"
      echo "    vmsvc.handler = file"
      echo "    vmsvc.data = /var/log/vmsvc.arc.log"
      echo "    vmtoolsd.level = debug"
      echo "    vmtoolsd.handler = file"
      echo "    vmtoolsd.data = /var/log/vmtoolsd.arc.log"
      echo "[powerops]"
      echo "    poweron-script = ${VMTOOLS_PATH}/etc/vmware-tools/poweron-vm-default"
      echo "    poweroff-script = ${VMTOOLS_PATH}/etc/vmware-tools/poweroff-vm-default"
      echo "    resume-script = ${VMTOOLS_PATH}/etc/vmware-tools/resume-vm-default"
      echo "    suspend-script = ${VMTOOLS_PATH}/etc/vmware-tools/suspend-vm-default"
    } >"/tmpRoot${VMWARE_CONF}"

    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo "After=network-online.target"
      echo
      echo "[Service]"
      echo "Type=forking"
      echo "PIDFile=${VMTOOLS_PID}"
      echo "Environment=PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      echo "Environment=LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:/usr/lib:/lib"
      echo "ExecStart=${VMTOOLS_PATH}/bin/vmtoolsd -c ${VMWARE_CONF} --common-path=${COMMON_PATH} --plugin-path=${PLUGINS_PATH} -b ${VMTOOLS_PID}"
      echo "ExecReload=/bin/kill -HUP \$MAINPID"
      echo "Restart=always"
      echo "RestartSec=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"/tmpRoot/usr/lib/systemd/system/vmtools.service"
  elif grep -Eq 'mev=kvm|mev=qemu' /proc/cmdline; then
    GUEST_AGENT="/dev/virtio-ports/org.qemu.guest_agent.0"
    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo "ConditionPathExists=${GUEST_AGENT}"
      echo
      echo "[Service]"
      echo "Type=forking"
      echo "PIDFile=${VMTOOLS_PID}"
      echo "Environment=PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      echo "Environment=LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:/usr/lib:/lib"
      echo "ExecStart=${VMTOOLS_PATH}/bin/qemu-ga -m virtio-serial -p ${GUEST_AGENT} -t /var/run/ -d -f ${VMTOOLS_PID}"
      echo "ExecReload=/bin/kill -HUP \$MAINPID"
      echo "Restart=always"
      echo "RestartSec=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"/tmpRoot/usr/lib/systemd/system/vmtools.service"
  else
    {
      echo "[Unit]"
      echo "Description=vmtools daemon"
      echo "IgnoreOnIsolate=true"
      echo "After=multi-user.target"
      echo
      echo "[Service]"
      echo "Type=oneshot"
      # echo "Type=forking"
      # echo "PIDFile=${VMTOOLS_PID}"
      echo "Environment=PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      echo "Environment=LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:/usr/lib:/lib"
      echo "ExecStart=-echo Unknown mev"
      # echo "ExecReload=/bin/kill -HUP \$MAINPID"
      # echo "Restart=always"
      # echo "RestartSec=10"
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"/tmpRoot/usr/lib/systemd/system/vmtools.service"
    exit 1
  fi

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/vmtools.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon vmtools - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/vmtools.service"

  rm -rf /tmpRoot/share/open-vm-tools
  rm -rf /tmpRoot/lib/open-vm-tools
  rm -rf /tmpRoot/etc/open-vm-tools
  rm -rf /tmpRoot/usr/vmtools
fi