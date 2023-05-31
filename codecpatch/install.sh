#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec Codecpatch"
  cp -vf /usr/sbin/codecpatch.sh /tmpRoot/usr/sbin/codecpatch.sh
  chmod 755 /tmpRoot/usr/sbin/codecpatch.sh

  DEST="/tmpRoot/usr/lib/systemd/system/codecpatch.service"
  echo "[Unit]"                               >${DEST}
  echo "Description=Patch synocodectool"     >>${DEST}
  echo "After=multi-user.target"             >>${DEST}
  echo                                       >>${DEST}
  echo "[Service]"                           >>${DEST}
  echo "Type=oneshot"                        >>${DEST}
  echo "RemainAfterExit=true"                >>${DEST}
  echo "ExecStart=/usr/bin/codecpatch.sh"    >>${DEST}
  echo                                       >>${DEST}
  echo "[Install]"                           >>${DEST}
  echo "WantedBy=multi-user.target"          >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /usr/lib/systemd/system/codecpatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/codecpatch.service
fi