#!/usr/bin/env ash

case "${1}" in
"early" | "jrExit")
  echo "Installing addon dbgutils ${1}"
  [ ! -L /usr/sbin/modinfo ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  loader-logs.sh "${1}"
  ;;
"rcExit")
  echo "Installing addon dbgutils ${1}"
  [ ! -L /usr/sbin/modinfo ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  loader-logs.sh "${1}"
  echo "Starting ttyd ..."
  if /usr/bin/lsof -Pi :7681 -sTCP:LISTEN -t >/dev/null; then
    echo "Port 7681 is already in use. Terminating the existing process..."
    /usr/bin/lsof -i :7681
  fi
  /usr/sbin/ttyd /usr/bin/ash -l &
  echo "Starting dufs ..."
  if /usr/bin/lsof -Pi :7304 -sTCP:LISTEN -t >/dev/null; then
    echo "Port 7304 is already in use. Terminating the existing process..."
    /usr/bin/lsof -i :7304
  fi
  /usr/sbin/dufs -A -p 7304 / &
  ;;
"late")
  echo "Installing addon dbgutils ${1}"
  [ ! -L /usr/sbin/modinfo ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  loader-logs.sh "${1}"

  echo "Installing addon dbgutils"
  echo "Killing ttyd ..."
  /usr/bin/killall ttyd
  echo "Killing dufs ..."
  /usr/bin/killall dufs

  echo "Copying utils"
  [ ! -L /tmpRoot/usr/sbin/modinfo ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modinfo
  cp -vf /usr/bin/bc /tmpRoot/usr/bin/
  cp -vf /usr/bin/dtc /tmpRoot/usr/bin/
  cp -vf /usr/bin/lsscsi /tmpRoot/usr/bin/
  cp -vf /usr/bin/nano /tmpRoot/usr/bin/
  cp -vf /usr/bin/strace /tmpRoot/usr/bin/
  cp -vf /usr/bin/lsof /tmpRoot/usr/bin/
  cp -vf /usr/bin/loader-logs.sh /tmpRoot/usr/bin/
  cp -vf /usr/sbin/ttyd /tmpRoot/usr/sbin/
  cp -vf /usr/sbin/dufs /tmpRoot/usr/sbin/

  loader-logs.sh late

  DEST="/tmpRoot/lib/systemd/system/savelogs.service"
  echo "[Unit]"                                      >${DEST}
  echo "Description=RR save logs for debug"         >>${DEST}
  echo                                              >>${DEST}
  echo "[Service]"                                  >>${DEST}
  echo "Type=oneshot"                               >>${DEST}
  echo "RemainAfterExit=yes"                        >>${DEST}
  echo "ExecStop=/bin/loader-logs.sh dsm"           >>${DEST}
  echo                                              >>${DEST}
  echo "[Install]"                                  >>${DEST}
  echo "WantedBy=multi-user.target"                 >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -vsf /lib/systemd/system/savelogs.service /tmpRoot/lib/systemd/system/multi-user.target.wants/savelogs.service
  ;;
*)
  echo "dbgutils nothing to do with argument ${1}"
  exit 0
  ;;
esac
