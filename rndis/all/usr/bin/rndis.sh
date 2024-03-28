#!/usr/bin/env ash

for I in $(ls -d /sys/class/net/usb* 2>/dev/null); do
  NAME=${I##*/}
  /sbin/ifconfig ${NAME} up || true
  if [ -x /usr/syno/sbin/synonet ]; then # DSM
    /usr/syno/sbin/synonet --dhcp ${NAME} || true
  fi
  if [ -x /sbin/udhcpc ]; then # junior
    if [ -f "/etc/dhcpc/dhcpcd-${NAME}.pid" ]; then
      kill -9 $(cat /etc/dhcpc/dhcpcd-${NAME}.pid)
      rm -f /etc/dhcpc/dhcpcd-${NAME}.pid
    fi
    /sbin/udhcpc -i ${NAME} -p /etc/dhcpc/dhcpcd-${NAME}.pid -b -x hostname:$(hostname) || true
  fi
done

exit 0
