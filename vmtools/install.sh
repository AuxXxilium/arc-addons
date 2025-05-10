#!/usr/bin/env sh
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_vmtools() {
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
  DEST="/tmpRoot/usr/lib/systemd/system/vmtools.service"

  if grep -Eq 'mev=vmware' /proc/cmdline; then
    setup_vmware_service "${DEST}"
  elif grep -Eq 'mev=kvm|mev=qemu' /proc/cmdline; then
    setup_kvm_service "${DEST}"
  else
    setup_unknown_service "${DEST}"
    exit 1
  fi

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/vmtools.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service
}

setup_vmware_service() {
  DEST=$1
  VMTOOLS_PATH="/usr/vmtools"
  VMWARE_CONF="${VMTOOLS_PATH}/etc/vmware-tools/tools.conf"
  COMMON_PATH="${VMTOOLS_PATH}/lib/open-vm-tools/plugins"
  PLUGINS_PATH="${COMMON_PATH}/vmsvc"

  mkdir -p /tmpRoot/usr/vmtools/etc/vmware-tools
  cat <<EOF >"/tmpRoot${VMWARE_CONF}"
[vmtools]
    disable-tools-version = false
[logging]
    log = true
    vmsvc.level = debug
    vmsvc.handler = file
    vmsvc.data = /var/log/vmsvc.arc.log
    vmtoolsd.level = debug
    vmtoolsd.handler = file
    vmtoolsd.data = /var/log/vmtoolsd.arc.log
[powerops]
    poweron-script = ${VMTOOLS_PATH}/etc/vmware-tools/poweron-vm-default
    poweroff-script = ${VMTOOLS_PATH}/etc/vmware-tools/poweroff-vm-default
    resume-script = ${VMTOOLS_PATH}/etc/vmware-tools/resume-vm-default
    suspend-script = ${VMTOOLS_PATH}/etc/vmware-tools/suspend-vm-default
EOF

  cat <<EOF >"${DEST}"
[Unit]
Description=vmtools daemon
IgnoreOnIsolate=true
After=multi-user.target

[Service]
Type=forking
PIDFile=${VMTOOLS_PID}
Environment=\"PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:\$PATH\"
Environment="LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:\$LD_LIBRARY_PATH"
ExecStart=/usr/vmtools/bin/vmtoolsd -c ${VMWARE_CONF} --common-path=${COMMON_PATH} --plugin-path=${PLUGINS_PATH} -b ${VMTOOLS_PID}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

setup_kvm_service() {
  DEST=$1

  GUEST_AGENT="/dev/virtio-ports/org.qemu.guest_agent.0"

  cat <<EOF >"${DEST}"
[Unit]
Description=vmtools daemon
IgnoreOnIsolate=true
After=multi-user.target
ConditionPathExists=${GUEST_AGENT}

[Service]
Type=forking
PIDFile=${VMTOOLS_PID}
Environment=\"PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:\$PATH\"
Environment="LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:\$LD_LIBRARY_PATH"
ExecStart=${VMTOOLS_PATH}/bin/qemu-ga -m virtio-serial -p ${GUEST_AGENT} -t /var/run/ -d -f ${VMTOOLS_PID}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

setup_unknown_service() {
  DEST=$1

  cat <<EOF >"${DEST}"
[Unit]
Description=vmtools daemon
IgnoreOnIsolate=true
After=multi-user.target

[Service]
Type=oneshot
Environment=\"PATH=${VMTOOLS_PATH}/bin:${VMTOOLS_PATH}/sbin:\$PATH\"
Environment="LD_LIBRARY_PATH=${VMTOOLS_PATH}/lib:\$LD_LIBRARY_PATH"
ExecStart=-echo Unknown mev

[Install]
WantedBy=multi-user.target
EOF
}

uninstall_vmtools() {
  echo "Uninstalling addon vmtools - ${1}"
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/vmtools.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/vmtools.service"

  rm -rf /tmpRoot/share/open-vm-tools
  rm -rf /tmpRoot/lib/open-vm-tools
  rm -rf /tmpRoot/etc/open-vm-tools
  rm -rf /tmpRoot/usr/vmtools
}

case "${1}" in
  late) install_vmtools "${1}" ;;
  uninstall) uninstall_vmtools "${1}" ;;
esac
exit 0