#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec i915SA"
  mkdir -p /tmpRoot/usr/i915/lib/firmware/i915
  mkdir -p /tmpRoot/usr/i915/lib/modules
  cp -vf /usr/i915/lib/firmware/i915/* /tmpRoot/usr/i915/lib/firmware/i915/
  cp -vf /usr/i915/lib/modules/* /tmpRoot/usr/i915/lib/modules/
  cp -vf /usr/sbin/i915.sh /tmpRoot/usr/sbin/i915.sh
  DEST="/tmpRoot/lib/systemd/system/i915.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable i915 for SA6400"                                   >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=true"                                                 >>${DEST}
  echo "ExecStart=/usr/sbin/i915.sh"                                          >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/i915.service /tmpRoot/lib/systemd/system/multi-user.target.wants/i915.service
fi