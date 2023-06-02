#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Copying lshw to HD"
  cp -vf /usr/sbin/lshw /tmpRoot/usr/sbin/lshw
  cp -vfr /usr/share/lshw /tmpRoot/usr/share/lshw
fi
