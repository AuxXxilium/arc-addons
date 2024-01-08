#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing daemon for addincards"

  MODEL="$(cat /proc/sys/kernel/syno_hw_version)"
  FILE="/tmpRoot/usr/syno/etc.defaults/adapter_cards.conf"

  [ ! -f "${FILE}.bak" ] && cp -f "${FILE}" "${FILE}.bak"
  echo -n "" >"${FILE}"
  for N in $(cat "${FILE}.bak" | grep '\['); do
    echo "${N}" >>"${FILE}"
    echo "${MODEL}=yes" >>"${FILE}"
  done
fi
