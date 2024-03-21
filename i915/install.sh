#!/usr/bin/env ash

if [ "${1}" = "patches" ]; then
  echo "Installing addon i915 - ${1}"

  if [ -n "${2}" ]; then
    GPU="$(echo "${2}" | sed 's/://g' | tr '[:upper:]' '[:lower:]')"
  else
    GPU="$(lspci -n | grep 0300 | grep 8086 | cut -d " " -f 3 | sed 's/://g')"
    [ -z "${GPU}" ] && GPU="$(lspci -n | grep 0380 | grep 8086 | cut -d " " -f 3 | sed -e 's/://g')"
  fi
  [ -z "${GPU}" -o $(echo -n "${GPU}" | wc -c) -ne 8 ] && echo "GPU is not detected" && exit 0

  KO_FILE="/usr/lib/modules/i915.ko"
  [ ! -f "${KO_FILE}" ] && echo "i915.ko does not exist" && exit 0

  if [ -n "${2}" ] || grep -iq ${GPU} /usr/bin/i915ids 2>/dev/null; then
    isLoad=0
    if lsmod | grep -q ^i915; then
      isLoad=1
      rmmod i915
    fi
    GPU_DEF="86800000923e0000"
    GPU_BIN="${GPU:2:2}${GPU:0:2}0000${GPU:6:2}${GPU:4:2}0000"
    echo "GPU:${GPU} GPU_BIN:${GPU_BIN}"
    cp -vf "${KO_FILE}" "${KO_FILE}.bak"
    xxd -c $(xxd -p "${KO_FILE}.bak" | wc -c) -p "${KO_FILE}.bak" | sed "s/${GPU_DEF}/${GPU_BIN}/; s/308201f706092a86.*70656e6465647e0a//" | xxd -r -p > "${KO_FILE}"
    [ "${isLoad}" = "1" ] && /usr/sbin/modprobe "/usr/lib/modules/i915.ko"
  fi
elif [ "${1}" = "late" ]; then
  echo "Installing addon i915 - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  [ ! -f "${KO_FILE}.bak" ] && cp -vf "${KO_FILE}" "${KO_FILE}.bak"
  cp -vf "/usr/lib/modules/i915.ko" "${KO_FILE}"
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon i915 - ${1}"

  KO_FILE="/tmpRoot/usr/lib/modules/i915.ko"
  [ -f "${KO_FILE}.bak" ] && mv -f "${KO_FILE}.bak" "${KO_FILE}"
fi
