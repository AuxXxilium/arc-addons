#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

export LD_LIBRARY_PATH=/tmpRoot/usr/bin:/tmpRoot/usr/lib

check_build() {
  _BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"
  if [ ${_BUILD:-64570} -lt 69057 ]; then
    echo "${_BUILD} is not supported nvmesystem addon!"
    exit 0
  fi
}

install_early() {
  echo "Installing addon nvmesystem - early"

  # System volume is assembled with SSD Cache only, please remove SSD Cache and then reboot
  sed -i "s/support_ssd_cache=.*/support_ssd_cache=\"no\"/" /etc/synoinfo.conf /etc.defaults/synoinfo.conf

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -f "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/4584ed74b7488b4c24083b01/4584ed75b7488b4c24083b01/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"
}

install_late() {
  echo "Installing addon nvmesystem - late"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  # disk/shared_disk_info_enum.c::84 Failed to allocate list in SharedDiskInfoEnum, errno=0x900.
  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"

  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/0f95c00fb6c0488b94240810/0f94c00fb6c0488b94240810/; s/8944240c8b44240809e84409/8944240c8b44240890904409/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # Create storage pool page without RAID type.
  cp -vpf /usr/bin/nvmesystem.sh /tmpRoot/usr/bin/nvmesystem.sh

  [ ! -f "/tmpRoot/usr/bin/gzip" ] && cp -vpf /usr/bin/gzip /tmpRoot/usr/bin/gzip

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/nvmesystem.service"
  {
    echo "[Unit]"
    echo "Description=Modify storage panel(nvmesystem)"
    echo "Wants=smpkg-custom-install.service pkgctl-StorageManager.service"
    echo "After=smpkg-custom-install.service"
    echo "After=storagepanel.service" # storagepanel
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/nvmesystem.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/nvmesystem.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service

  # A bug in the custom kernel, the reason for which is currently unknown
  if cat /proc/version 2>/dev/null | grep -q 'RR@RR'; then
    ONBOOTUP=""
    ONBOOTUP="${ONBOOTUP}systemctl restart systemd-udev-trigger.service\n"
    ONBOOTUP="${ONBOOTUP}echo \"DELETE FROM task WHERE task_name LIKE ''ARCONBOOTUPARC_UDEV'';\" | sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db\n"

    ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
    if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -qw "task"; then
      echo "copy esynoscheduler.db"
      mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
      cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
    fi
    echo "insert ARCONBOOTUPARC_UDEV task to esynoscheduler.db"
    /tmpRoot/usr/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'ARCONBOOTUPARC_UDEV';
INSERT INTO task VALUES('ARCONBOOTUPARC_UDEV', '', 'bootup', '', 1, 0, 0, 0, '', 0, '$(echo -e ${ONBOOTUP})', 'script', '{}', '', '', '{}', '{}');
EOF
  fi
}

uninstall_addon() {
  echo "Uninstalling addon nvmesystem - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/nvmesystem.service"

  # rm -f /tmpRoot/usr/bin/gzip
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/nvmesystem.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/nvmesystem.sh" >>/tmpRoot/usr/arc/revert.sh
}

case "${1}" in
  early)
    check_build
    install_early
    ;;
  late)
    check_build
    install_late
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac
exit 0