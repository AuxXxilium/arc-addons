#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

MODES="config recovery junior automated update"

function use() {
  echo "Use: ${0} config|recovery|junior|automated|update"
  exit 1
}

# Sanity checks
if [ ! ${USER} = "root" ]; then
  exec sudo $0 $@
fi
[ -z "${1}" ] && use
if ! echo "${MODES}" | grep -qw "${1}"; then use; fi
echo "Rebooting to ${1} mode"
echo 1 >/proc/sys/kernel/syno_install_flag
mount /dev/synoboot1 /mnt
GRUBPATH="$(dirname $(find /mnt/ -name grub.cfg | head -1))"
ENVFILE="${GRUBPATH}/grubenv"
[ ! -f "${ENVFILE}" ] && grub-editenv ${ENVFILE} create

grub-editenv ${ENVFILE} set next_entry="${1}"
umount /mnt
[ -x /usr/syno/sbin/synopoweroff ] &&
  /usr/syno/sbin/synopoweroff -r ||
  reboot