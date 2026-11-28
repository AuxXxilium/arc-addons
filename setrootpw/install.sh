#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# setrootpw: root's password and SSH/SFTP for root, set from the loader.
#
# The password is chosen in the loader (Arc's addon menu, Arx's web page)
# and kept there only as a SHA-512 crypt hash ($6$...), which the loader
# passes as ${2}. It used to be typed into a Task Scheduler task in DSM --
# no help to someone who forgot the password and cannot log in to DSM, which
# is what this addon is for.
#
# At "late" the hash goes into DSM's /etc/shadow as root's password, but only
# when it differs from the one this addon set last time (a marker next to
# /etc/shadow keeps a checksum of it): a password changed in DSM afterwards
# stays until the loader's is changed again. Then, once DSM is up, a one-shot
# service puts root in administrators and switches SSH on, as the task did.

HASH="${2:-}"
MARK="/tmpRoot/etc/.arc-setrootpw"
UNIT="/tmpRoot/usr/lib/systemd/system/arc-setrootpw.service"

# The old task held the password in clear: removed once the loader passes a
# hash, which replaces it.
drop_old_task() {
  export LD_LIBRARY_PATH=/tmpRoot/usr/bin:/tmpRoot/usr/lib
  DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  [ -f "${DB}" ] && [ -x /tmpRoot/usr/bin/sqlite3 ] || return 0
  echo "DELETE FROM task WHERE task_name LIKE 'SetRootPw';" | /tmpRoot/usr/bin/sqlite3 "${DB}" 2>/dev/null || true
}

legacy_task() {
  if [ ! -f /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db ]; then
    mkdir -p /tmpRoot/usr/syno/etc/esynoscheduler
    cp -pf /addons/esynoscheduler.db /tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db
  fi
  export LD_LIBRARY_PATH=/tmpRoot/usr/bin:/tmpRoot/usr/lib
  DB="/tmpRoot/usr/syno/etc/esynoscheduler/esynoscheduler.db"
  if echo "SELECT * FROM task;" | /tmpRoot/usr/bin/sqlite3 "${DB}" | grep -q "SetRootPw||bootup||1|0|0|0|"; then
    echo "setrootpw task already exists and it is enabled"
    return 0
  fi
  /tmpRoot/usr/bin/sqlite3 "${DB}" <<EOF
DELETE FROM task WHERE task_name LIKE 'SetRootPw';
INSERT INTO task VALUES('SetRootPw', '', 'bootup', '', 1, 0, 0, 0, '', 0, '
PW=""    # Please change to the password you need.
[ -n "\${PW}" ] && /usr/syno/sbin/synouser --setpw root \${PW} && synogroup --memberadd administrators root && systemctl restart sshd
synowebapi -s --exec api=SYNO.Core.Terminal method=set version=3 enable_ssh=true ssh_port=22
', 'script', '{}', '', '', '{}', '{}');
EOF
}

if [ "${1}" = "late" ]; then
  echo "Installing addon setrootpw - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  mkdir -p /tmpRoot/usr/lib/openssh
  cp -vpf /usr/lib/openssh/sftp-server /tmpRoot/usr/lib/openssh/sftp-server

  FILE="/tmpRoot/etc/ssh/sshd_config"
  /usr/bin/arc-backup.sh take "${FILE}"

  cp -pf "${FILE}.bak" "${FILE}"
  sed -i 's|^.*PermitRootLogin .*$|PermitRootLogin yes|' ${FILE}
  sed -i 's|^Subsystem.*$|Subsystem	sftp	/usr/lib/openssh/sftp-server|' ${FILE}
  /usr/bin/arc-backup.sh seal "${FILE}"

  # Only a SHA-512 crypt hash: $6$<salt>$<86 characters>, optionally with
  # rounds=. Anything else is not a password this loader made.
  case "${HASH}" in
    '$6$'*) drop_old_task ;;
    "")
      # A loader that passes no hash (one from before 2026-11-28, or no
      # password chosen yet): the Task Scheduler task as before, so updating
      # the addon alone takes nothing away.
      echo "setrootpw: no password from the loader; the SetRootPw task in DSM's Task Scheduler sets it"
      legacy_task
      exit 0
      ;;
    *)
      echo "setrootpw: the loader's value is not a SHA-512 crypt hash, ignored"
      exit 0
      ;;
  esac
  if ! printf '%s' "${HASH}" | grep -qE '^\$6\$(rounds=[0-9]+\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$'; then
    echo "setrootpw: the loader's value is not a SHA-512 crypt hash, ignored"
    exit 0
  fi

  SUM="$(printf '%s' "${HASH}" | sha256sum | cut -d' ' -f1)"
  if [ -f "${MARK}" ] && [ "$(cat "${MARK}" 2>/dev/null)" = "${SUM}" ]; then
    echo "setrootpw: the loader's password was set before; left as it is"
    exit 0
  fi

  SHADOW="/tmpRoot/etc/shadow"
  [ -f "${SHADOW}" ] || { echo "setrootpw: no /etc/shadow in DSM"; exit 0; }
  # root's line with the new hash, the other fields kept; lastchg today.
  DAYS=$(( $(date +%s) / 86400 ))
  TMP="${SHADOW}.arc-setrootpw"
  if grep -q '^root:' "${SHADOW}"; then
    awk -F: -v OFS=: -v h="${HASH}" -v d="${DAYS}" \
      '$1 == "root" { $2 = h; $3 = d } { print }' "${SHADOW}" >"${TMP}"
  else
    { cat "${SHADOW}"; echo "root:${HASH}:${DAYS}:0:99999:7:::"; } >"${TMP}"
  fi
  if [ -s "${TMP}" ] && grep -q "^root:${HASH}:" "${TMP}"; then
    chmod --reference="${SHADOW}" "${TMP}" 2>/dev/null || chmod 600 "${TMP}"
    chown --reference="${SHADOW}" "${TMP}" 2>/dev/null || true
    mv -f "${TMP}" "${SHADOW}"
    printf '%s\n' "${SUM}" >"${MARK}"
    chmod 600 "${MARK}"
    echo "setrootpw: root's password set from the loader"
  else
    rm -f "${TMP}"
    echo "setrootpw: could not write /etc/shadow"
    exit 0
  fi

  # Once DSM is up: root in administrators and SSH on, as the old task did.
  # It removes itself after running, so it only follows a change.
  mkdir -p "$(dirname "${UNIT}")" /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  cat >"${UNIT}" <<'EOF'
[Unit]
Description=Arc setrootpw: root in administrators and SSH on
After=multi-user.target

[Service]
Type=oneshot
ExecStart=-/bin/sh -c '/usr/syno/sbin/synogroup --memberadd administrators root; /usr/syno/bin/synowebapi -s --exec api=SYNO.Core.Terminal method=set version=3 enable_ssh=true ssh_port=22; systemctl restart sshd'
ExecStartPost=-/bin/sh -c 'rm -f /usr/lib/systemd/system/multi-user.target.wants/arc-setrootpw.service /usr/lib/systemd/system/arc-setrootpw.service'

[Install]
WantedBy=multi-user.target
EOF
  ln -sf /usr/lib/systemd/system/arc-setrootpw.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-setrootpw.service

elif [ "${1}" = "uninstall" ]; then
  echo "Uninstalling addon setrootpw - ${1}"

  rm -f /tmpRoot/usr/lib/openssh/sftp-server

  FILE="/tmpRoot/etc/ssh/sshd_config"
  /usr/bin/arc-backup.sh restore "${FILE}"

  # root keeps the password it has; only what this addon added goes.
  rm -f "${MARK}" "${UNIT}" /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-setrootpw.service
  drop_old_task
fi
