#!/usr/bin/env ash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

install_addon() {
  echo "Installing addon setrootpw - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/usr/lib/openssh
  cp -vpf /usr/lib/openssh/sftp-server /tmpRoot/usr/lib/openssh/sftp-server
  [ ! -f "/tmpRoot/usr/lib/libcrypto.so.3" ] && cp -vpf /usr/lib/libcrypto.so.3 /tmpRoot/usr/lib/libcrypto.so.3

  FILE="/tmpRoot/etc/ssh/sshd_config"
  [ ! -f "${FILE}.bak" ] && cp -pf "${FILE}" "${FILE}.bak"

  cp -pf "${FILE}.bak" "${FILE}"
  sed -i 's|^.*PermitRootLogin.*$|PermitRootLogin yes|' ${FILE}
  sed -i 's|^Subsystem.*$|Subsystem	sftp	/usr/lib/openssh/sftp-server|' ${FILE}

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ ! -f "${ESYNOSCHEDULER_DB}" ] || ! /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" ".tables" | grep -wq "task"; then
    echo "copy esynoscheduler.db"
    mkdir -p "$(dirname "${ESYNOSCHEDULER_DB}")"
    cp -vpf /addons/esynoscheduler.db "${ESYNOSCHEDULER_DB}"
  fi
  if echo "SELECT * FROM task;" | /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" | grep -q "SetRootPw||bootup||1|0|0|0||0|"; then
    echo "setrootpw task already exists and it is enabled"
  else
    echo "insert setrootpw task to esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'SetRootPw';
INSERT INTO task VALUES('SetRootPw', '', 'bootup', '', 0, 0, 0, 0, '', 0, '
PW=""    # Please change to the password you need.
[ -n "\${PW}" ] && /usr/syno/sbin/synouser --setpw root \${PW} && synogroup --memberadd administrators root && systemctl restart sshd
synowebapi --exec api=SYNO.Core.Terminal method=set version=3 enable_ssh=true ssh_port=22
', 'script', '{}', '', '', '{}', '{}');
EOF
  fi
}

uninstall_addon() {
  echo "Uninstalling addon setrootpw - ${1}"

  rm -f /tmpRoot/usr/lib/openssh/sftp-server
  # rm -f /tmpRoot/usr/lib/libcrypto.so.3

  FILE="/tmpRoot/etc/ssh/sshd_config"
  [ -f "${FILE}.bak" ] && mv -f "${FILE}.bak" "${FILE}"

  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  ESYNOSCHEDULER_DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if [ -f "${ESYNOSCHEDULER_DB}" ]; then
    echo "delete setrootpw task from esynoscheduler.db"
    /tmpRoot/bin/sqlite3 "${ESYNOSCHEDULER_DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'SetRootPw';
EOF
  fi
}

case "${1}" in
  late)
    install_addon "${1}"
    ;;
  uninstall)
    uninstall_addon "${1}"
    ;;
  *)
    exit 0
    ;;
esac