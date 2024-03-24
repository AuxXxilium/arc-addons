#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon photosfacepatch - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"
  
  echo "Creating service to exec photosfacepatch"
  cp -vf /usr/bin/photosfacepatch.sh /tmpRoot/usr/bin/photosfacepatch.sh
  cp -vf /usr/bin/PatchELFSharp /tmpRoot/usr/bin/PatchELFSharp
  
  DEST="/tmpRoot/usr/lib/systemd/system/photosfacepatch.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable photosfacepatch"                                   >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "Type=oneshot"                                                         >>${DEST}
  echo "RemainAfterExit=yes"                                                  >>${DEST}
  echo "ExecStart=/usr/bin/photosfacepatch.sh"                                >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -vp /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/photosfacepatch.service /tmpRoot/lib/systemd/system/multi-user.target.wants/photosfacepatch.service
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon photosfacepatch - ${1}"
  #TODO: Add uninstall code here
fi
