#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and PeterSuh-Q3 <https://github.com/PeterSuh-Q3>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set_key_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  [ ! -f "$file" ] && touch "$file"

  value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  if grep -q "^${key}=" "$file"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
if [ -x "/bin/set_key_value" ]; then
  SKV="/bin/set_key_value"
elif [ -x "/usr/syno/bin/synosetkeyvalue" ]; then
  SKV="/usr/syno/bin/synosetkeyvalue"
else
  SKV="set_key_value"
fi
_log() { echo "[install] $*"; /bin/logger -p info -t install "$@"; }

copy_files_patches() {
  mkdir -p /usr/lib/udev/rules.d
  cat > /usr/lib/udev/rules.d/04-system-disk-dtb.rules <<"EOF"
ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{DEVNAME}=="/dev/nvme*|/dev/sas*|/dev/usb*|/dev/sd*|/dev/sata*", PROGRAM=="/usr/bin/disks.sh --update %E{DEVNAME}"
EOF
}

copy_files_late() {
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"
  cp -vpf /usr/bin/disks.sh /tmpRoot/usr/bin/disks.sh
}

sync_synoinfo_keys() {
  KVLIST="maxdisks supportnvme support_m2_pool usbportcfg esataportcfg internalportcfg supportportmappingv2"
  for K in $KVLIST; do
    V=$($GKV /etc.defaults/synoinfo.conf $K)
    for F in /etc/synoinfo.conf /etc.defaults/synoinfo.conf; do $SKV "$F" "$K" "$V"; done
    _log "$K=$V"
  done
}

late_stage_nvme_patch() {
  /usr/bin/disks.sh --nvme-late-patch
}

cleanup_files() {
  rm -f /usr/bin/disks.sh /usr/bin/dtc /etc/model.dtb
  rm -f /usr/lib/udev/rules.d/04-system-disk-dtb.rules
  rm -rf /etc/nvmePorts
}

case "$1" in
  patches)
    copy_files_patches
    sync_synoinfo_keys
    /usr/bin/disks.sh --create
    ;;
  late)
    copy_files_late
    /usr/bin/disks.sh --update /tmpRoot
    late_stage_nvme_patch
    ;;
  uninstall)
    cleanup_files
    ;;
  *)
    echo "Usage: $0 {patches|late|uninstall}"
    ;;
esac