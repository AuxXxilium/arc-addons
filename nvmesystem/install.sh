#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# PLATFORMS="epyc7002"
# PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
# if ! echo "${PLATFORMS}" | grep -qw "${PLATFORM}"; then
#   echo "${PLATFORM} is not supported nvmesystem addon!"
#   exit 0
# fi
_BUILD="$(/bin/get_key_value /etc.defaults/VERSION buildnumber)"
if [ ${_BUILD:-64570} -lt 69057 ]; then
  echo "${_BUILD} is not supported nvmesystem addon!"
  exit 0
fi

if [ "${1}" = "early" ]; then
  echo "Installing addon nvmesystem - ${1}"

  # System volume is assembled with SSD Cache only, please remove SSD Cache and then reboot
  sed -i "s/support_ssd_cache=.*/support_ssd_cache=\"no\"/" /etc/synoinfo.conf /etc.defaults/synoinfo.conf

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"
  cp -f "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/4584ed74b7488b4c24083b01/4584ed75b7488b4c24083b01/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

elif [ "${1}" = "late" ]; then
  echo "Installing addon nvmesystem - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  # disk/shared_disk_info_enum.c::84 Failed to allocate list in SharedDiskInfoEnum, errno=0x900.
  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"

  cp -vf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
    sed "s/0f95c00fb6c0488b94240810/0f94c00fb6c0488b94240810/; s/8944240c8b44240809e84409/8944240c8b44240890904409/" |
    xxd -r -p >"${SO_FILE}" 2>/dev/null
  rm -f "${SO_FILE}.tmp"

  # Create storage pool page without RAID type.
  cp -vf /usr/bin/nvmesystem.sh /tmpRoot/usr/bin/nvmesystem.sh

  [ ! -f "/tmpRoot/usr/bin/gzip" ] && cp -vf /usr/bin/gzip /tmpRoot/usr/bin/gzip

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/nvmesystem.service"
  echo "[Unit]"                                          >${DEST}
  echo "Description=Modify storage panel"               >>${DEST}
  echo "After=multi-user.target"                        >>${DEST}
  echo "After=synoscgi.service"                         >>${DEST}
  echo "After=storagepanel.service"                     >>${DEST}  # storagepanel
  echo                                                  >>${DEST}
  echo "[Service]"                                      >>${DEST}
  echo "Type=oneshot"                                   >>${DEST}
  echo "RemainAfterExit=yes"                            >>${DEST}
  echo "ExecStart=/usr/bin/nvmesystem.sh"               >>${DEST}
  echo                                                  >>${DEST}
  echo "[Install]"                                      >>${DEST}
  echo "WantedBy=multi-user.target"                     >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/nvmesystem.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service

  # A bug in the custom kernel, the reason for which is currently unknown
  if cat /proc/version 2>/dev/null | grep -q 'RR@RR'; then
    ONBOOTUP=""
    ONBOOTUP="${ONBOOTUP}systemctl restart systemd-udev-trigger.service\n"
    ONBOOTUP="${ONBOOTUP}echo \"DELETE FROM task WHERE task_name LIKE ''ARCONBOOTUPARC_UDEV'';\" | sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db\n"
    echo "insert reboottoloader task to esynoscheduler.db"
    export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
    /tmpRoot/bin/sqlite3 /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db <<EOF
DELETE FROM task WHERE task_name LIKE 'ARCONBOOTUPARC_UDEV';
INSERT INTO task VALUES('ARCONBOOTUPARC_UDEV', '', 'bootup', '', 1, 0, 0, 0, '', 0, '$(echo -e ${ONBOOTUP})', 'script', '{}', '', '', '{}', '{}');
EOF
  fi

elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon nvmesystem - ${1}"

  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ -f "${SO_FILE}.bak" ] && mv -f "${SO_FILE}.bak" "${SO_FILE}"

  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/nvmesystem.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/nvmesystem.service"

  # rm -f /tmpRoot/usr/bin/gzip
  [ ! -f "/tmpRoot/usr/arc/revert.sh" ] && echo '#!/usr/bin/env bash' >/tmpRoot/usr/arc/revert.sh && chmod +x /tmpRoot/usr/arc/revert.sh
  echo "/usr/bin/nvmesystem.sh -r" >>/tmpRoot/usr/arc/revert.sh
  echo "rm -f /usr/bin/nvmesystem.sh" >>/tmpRoot/usr/arc/revert.sh
fi