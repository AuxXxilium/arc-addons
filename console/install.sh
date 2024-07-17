#!/usr/bin/env ash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORMS="apollolake geminilake epyc7002"
PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"
if ! echo "${PLATFORMS}" | grep -qw "${PLATFORM}"; then
  echo "${PLATFORM} is not supported console addon!"
  exit 0
fi

if [ "${1}" = "early" ]; then
  echo "Installing addon console - ${1}"
  tar -zxf /addons/console-7.1.tgz -C /usr/

elif [ "${1}" = "modules" ]; then
  echo "Installing addon console - ${1}"
  if [ -n "${2}" ]; then
    /usr/sbin/modprobe ${2}
  else
    for M in i915 efifb vesafb vga16fb; do
      [ -e /sys/class/graphics/fb0 ] && break
      /usr/sbin/modprobe ${M}
    done
  fi
  /usr/sbin/modprobe fb
  /usr/sbin/modprobe fbcon
  echo "Arc console - wait..." >/dev/tty1
  # Workaround for DVA1622
  if [ "${MODEL}" = "DVA1622" ]; then
    echo >/dev/tty2
    /usr/bin/ioctl /dev/tty0 22022 -v 2
    /usr/bin/ioctl /dev/tty0 22022 -v 1
  fi
elif [ "${1}" = "rcExit" ]; then
  # echo "Installing addon console - ${1}"
  # Run only in junior mode (DSM not installed)
  echo -e "Junior mode\n" >/etc/issue
  echo "Starting getty..."
  /usr/sbin/getty -L 0 tty1 &
  /usr/bin/loadkeys /usr/share/keymaps/i386/${LAYOUT:-qwerty}/${KEYMAP:-us}.map.gz
  # Workaround for DVA1622
  if [ "${MODEL}" = "DVA1622" ]; then
    echo >/dev/tty2
    /usr/bin/ioctl /dev/tty0 22022 -v 2
    /usr/bin/ioctl /dev/tty0 22022 -v 1
  fi
elif [ "${1}" = "late" ]; then
  echo "Installing addon console - ${1}"
  mkdir -p "/tmpRoot/usr/arc/addons/"
  cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

  tar -zxf /addons/console-7.1.tgz -C /tmpRoot/usr/
  # run when boot installed DSM
  echo -e "DSM mode\n" >/tmpRoot/etc/issue
  if [ ! -f /tmpRoot/usr/lib/systemd/system/getty\@.service ]; then # misc addon is do this
    cp -fv /tmpRoot/usr/lib/systemd/system/serial-getty\@.service /tmpRoot/usr/lib/systemd/system/getty\@.service
    sed -i 's|^ExecStart=.*|ExecStart=-/sbin/agetty %I 115200 linux|' /tmpRoot/usr/lib/systemd/system/getty\@.service
  fi
  if [ ! -f /tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@tty1.service ]; then
    mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
    ln -vsf /usr/lib/systemd/system/getty\@.service /tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@tty1.service
  fi
  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/keymap.service"
  echo "[Unit]"                                                                                      >${DEST}
  echo "Description=Configure keymap"                                                               >>${DEST}
  echo "After=getty.target"                                                                         >>${DEST}
  echo                                                                                              >>${DEST}
  echo "[Service]"                                                                                  >>${DEST}
  echo "Type=oneshot"                                                                               >>${DEST}
  echo "RemainAfterExit=yes"                                                                        >>${DEST}
  echo "ExecStart=/usr/bin/loadkeys /usr/share/keymaps/i386/${LAYOUT:-qwerty}/${KEYMAP:-us}.map.gz" >>${DEST}
  echo                                                                                              >>${DEST}
  echo "[Install]"                                                                                  >>${DEST}
  echo "WantedBy=multi-user.target"                                                                 >>${DEST}

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/keymap.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/keymap.service
  # Workaround for DVA1622
  if [ "${MODEL}" = "DVA1622" ]; then
    echo >/dev/tty2
    /usr/bin/ioctl /dev/tty0 22022 -v 2
    /usr/bin/ioctl /dev/tty0 22022 -v 1
  fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon console - ${1}"

  rm -f "/tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@tty1.service"
  # rm -f "/tmpRoot/usr/lib/systemd/system/getty\@.service"  # Do not remove, used by misc addons
  rm -f "/tmpRoot/usr/lib/systemd/system/multi-user.target.wants/keymap.service"
  rm -f "/tmpRoot/usr/lib/systemd/system/keymap.service"

  rm -rf /tmpRoot/usr/share/consolefonts
  rm -rf /tmpRoot/usr/share/keymaps
  rm -f /tmpRoot/usr/bin/chvt
  rm -f /tmpRoot/usr/bin/deallocvt
  rm -f /tmpRoot/usr/bin/loadkeys
  rm -f /tmpRoot/usr/bin/setleds
  rm -f /tmpRoot/usr/bin/ioctl
fi