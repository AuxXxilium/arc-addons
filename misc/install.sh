#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

PLATFORM="$(/bin/get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2)"

if [ "${1}" = "early" ]; then
  echo "Installing addon misc - ${1}"

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -pf "${SO_FILE}" "${SO_FILE}.bak"
  cp -pf "${SO_FILE}" "${SO_FILE}.tmp"
  xxd -c "$(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c)" -p "${SO_FILE}.tmp" 2>/dev/null \
    | sed "s/2d6520302e39/2d6520312e32/" \
    | xxd -r -p >"${SO_FILE}.new" 2>/dev/null
  ORIG_SIZE="$(wc -c <"${SO_FILE}.tmp" 2>/dev/null)"
  NEW_SIZE="$(wc -c <"${SO_FILE}.new" 2>/dev/null)"
  if [ -n "${NEW_SIZE}" ] && [ "${NEW_SIZE}" = "${ORIG_SIZE}" ]; then
    # Write in place (not mv) so the existing inode/mode (incl. exec bit) is kept -
    # mv would replace it with .new's fresh, umask-based mode and drop +x.
    cat "${SO_FILE}.new" >"${SO_FILE}"
  else
    echo "WARNING: scemd patch produced unexpected output (size ${NEW_SIZE:-0} vs ${ORIG_SIZE:-0}), leaving file untouched"
  fi
  rm -f "${SO_FILE}.new"
  rm -f "${SO_FILE}.tmp"

  if echo "epyc7003ntb" | grep -wq "${PLATFORM}"; then
    # for epyc7003ntb console error "sh: invalid number 'Read error'"
    sed -i 's/^main "\$@"$/# main "\$@"/' "/usr/syno/sbin/i2c_hb_checker.sh" 2>/dev/null || true
    sed -i -E 's/169\.254\.4\.(1|2)/127.0.0.1/g; s/ --interface ntb_eth[0-9]{1,2}//g; s/check_ntb_connection$/exit 0 # check_ntb_connection/' /usr/syno/share/clusterInstall.sh || true

    # synomulticontroller is a symlink to scemd (the multicall HA/NTB daemon binary).
    # On a single-node redpill box there's no real NTB peer, so the genuine binary
    # blocks scemd's apply-lock/HA identity checks (--up_lock_ctrl, --location, etc.)
    # waiting on a peer that will never answer, which stalls synoconfstored/nginx
    # and leaves the WebUI unreachable even though the DSM install itself completed.
    # Replace it with a shim that always reports "no peer, degraded, lock granted".
    SMC="/usr/syno/bin/synomulticontroller"
    # Must rm the symlink first, not overwrite through it - it points at the real
    # scemd daemon binary, and writing through the link would corrupt scemd itself.
    if [ -e "${SMC}" ]; then
      rm -f "${SMC}"
      cat >"${SMC}" <<'EOF'
#!/bin/sh
# Single-node synomulticontroller shim (epyc7003ntb, no NTB peer).
for a in "$@"; do
  case "${a}" in
    --location)            echo "location:0"; exit 0 ;;
    --check_chassis_match) echo "Chassis match"; exit 0 ;;
    --is_remote_power_on)  exit 1 ;;
    --ntb_heartbeat_check) echo "Current link is down"; exit 1 ;;
    --link_status)         echo "link down"; exit 1 ;;
  esac
done
# Lock/apply calls etc: no peer to coordinate with, treat as success.
exit 0
EOF
      chmod +x "${SMC}"
    fi

    # PAS7700 runs DSM Enterprise as an FSDN dual-pool system: the system sits
    # on a "meta" NVMe namespace with its own small partition layout (v200:
    # 128 MB md0, 8 MB md1). Plain disks have no namespaces, so the installer
    # found no system disk ("Cannot to get meta ns"), and with dual pool off it
    # still took v200 - the layout raidtool uses when partition_curr_version
    # is missing - whose md0 cannot hold DSM. Single pool and the standard
    # DSM 7 layout (v9: 8 GB md0, 2 GB md1) install on any disk.
    for F in /etc/synoinfo.conf /etc.defaults/synoinfo.conf; do
      /bin/set_key_value "${F}" "support_dual_pool" "no"
      /bin/set_key_value "${F}" "partition_curr_version" "9"
    done
  fi

elif [ "${1}" = "patches" ]; then
  # getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -Eo 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -wq "${TTYN}" && continue
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Starting getty on ${TTYN}"
      if [ -n "${BAUD}" ]; then
        /usr/sbin/getty -L "${TTYN}" "${BAUD}" linux &
      else
        /usr/sbin/getty -L "${TTYN}" linux &
      fi
    fi
  done

  # network
  if grep -Eq '(^| )network\.[0-9a-fA-F:]{12,17}=' /proc/cmdline; then
    for I in $(tr ' ' '\n' </proc/cmdline | grep -E '^network\.[0-9a-fA-F:]{12,17}='); do
      MACR="$(echo "${I}" | cut -d. -f2 | cut -d= -f1 | sed 's/://g; s/.*/\L&/')"
      IPRS="$(echo "${I}" | cut -d= -f2)"
      for F in $(LC_ALL=C printf '%s\n' /sys/class/net/eth* | sort -V); do
        [ ! -e "${F}" ] && continue
        ETH="$(basename "${F}")"
        MACX=$(cat "/sys/class/net/${ETH}/address" 2>/dev/null | sed 's/://g; s/.*/\L&/')
        if [ "${MACR}" = "${MACX}" ]; then
          echo "Setting IP for ${ETH} to ${IPRS}"
          F="/etc/sysconfig/network-scripts/ifcfg-${ETH}"
          BRIDGE=$(/bin/get_key_value "${F}" "BRIDGE")
          [ -n "${BRIDGE}" ] && F="/etc/sysconfig/network-scripts/ifcfg-${BRIDGE}"
          /bin/set_key_value "${F}" "BOOTPROTO" "static"
          /bin/set_key_value "${F}" "ONBOOT" "yes"
          /bin/set_key_value "${F}" "IPADDR" "$(echo "${IPRS}" | cut -d/ -f1)"
          /bin/set_key_value "${F}" "NETMASK" "$(echo "${IPRS}" | cut -d/ -f2)"
          /bin/set_key_value "${F}" "GATEWAY" "$(echo "${IPRS}" | cut -d/ -f3)"
          /etc/rc.network restart ${ETH} >/dev/null 2>&1
          [ -n "$(echo "${IPRS}" | cut -d/ -f4)" ] && /etc/rc.network_routing "$(echo "${IPRS}" | cut -d/ -f4)" &
        fi
      done
    done
  fi

elif [ "${1}" = "rcExit" ]; then
  echo "Installing addon misc - ${1}"

  # enable telnet
  sed -i 's/^root:x:0:0/root::0:0/' /etc/passwd
  inetd

  # invalid_disks
  # SH_FILE="/usr/syno/share/get_hcl_invalid_disks.sh"
  # [ -f "${SH_FILE}" ] && cp -pf "${SH_FILE}" "${SH_FILE}.bak" && printf '#!/bin/sh\nexit 0\n' >"${SH_FILE}"
  while true; do
    [ ! -f "/tmp/installable_check_pass" ] && touch "/tmp/installable_check_pass"
    sleep 1
  done & # using a while loop in case DSM is running in a VM

  # error message
  while true; do
    if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
      if [ ! -f /usr/syno/web/main.js.bak ]; then
        cp -f /usr/syno/web/main.js /usr/syno/web/main.js.bak
        sed -i 's/c("welcome","desc_install")/"Error: Boot disk mounting failed. Please change the USB port of the boot disk and refresh the page."/' /usr/syno/web/main.js 2>/dev/null
      fi
    else
      if [ -f /usr/syno/web/main.js.bak ]; then
        mv -f /usr/syno/web/main.js.bak /usr/syno/web/main.js
      fi
    fi
    sleep 1
  done &

  # The installer's httpd serves "/" from index.html (I:index.html in
  # /usr/syno/web/httpd.conf). DSM Enterprise for PAS7700 ships the Web
  # Assistant only as web_index.html, so "/" fell through to the 404 page, which
  # redirects back to "/": the installer never opened.
  if [ ! -e /usr/syno/web/index.html ] && [ -f /usr/syno/web/web_index.html ]; then
    ln -sf web_index.html /usr/syno/web/index.html
  fi

  # for epyc7003ntb web error
  if echo "epyc7003ntb" | grep -wq "${PLATFORM}"; then
    sed -i 's/check_ntb_connection$/exit 0 # check_ntb_connection/' "/usr/syno/share/clusterInstall.sh" 2>/dev/null || true
  fi

  # disable DisabledPortDisks
  sed -i 's/^DisabledPortDisks=.*$/DisabledPortDisks=""/' /usr/syno/web/webman/get_state.cgi 2>/dev/null

  # reboot
  sed -i 's/reboot$/reboot -f/' /usr/syno/web/webman/reboot.cgi 2>/dev/null

  # recovery
  if grep -wq "recovery" /proc/cmdline 2>/dev/null && [ -x /usr/syno/web/webman/recovery.cgi ]; then
    /usr/syno/web/webman/recovery.cgi
  fi

elif [ "${1}" = "jrExit" ]; then
  echo "Installing addon misc - ${1}"

  /usr/bin/wol.sh 2>/dev/null || true

elif [ "${1}" = "late" ]; then
  echo "Installing addon misc - ${1}"
  mkdir -vp /tmpRoot/usr/arc/addons
  # cp -pf "${0}" "/tmpRoot/usr/arc/addons/"

  echo "Killing ttyd dufs..."
  /usr/bin/killall ttyd 2>/dev/null || true
  /usr/bin/killall dufs 2>/dev/null || true

  # cp -pf /usr/sbin/ttyd /tmpRoot/usr/sbin/ttyd
  # cp -pf /usr/sbin/dufs /tmpRoot/usr/sbin/dufs

  # ethtool
  [ ! -f "/tmpRoot/usr/bin/ethtool" ] && cp -pf /usr/bin/ethtool /tmpRoot/usr/bin/ethtool

  # synoinfo.conf
  cp -vpf "/addons/synoinfo.conf" "/tmpRoot/usr/arc/addons/synoinfo.conf"
  for KEY in $(cat "/addons/synoinfo.conf" 2>/dev/null | cut -d= -f1); do
    [ -z "${KEY}" ] && continue
    VALUE="$(/bin/get_key_value /addons/synoinfo.conf "${KEY}")"
    echo "Setting ${KEY} to ${VALUE}"
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "${KEY}" "${VALUE}"; done
  done

  # PAS7700: single pool, standard layout (see "early").
  if echo "epyc7003ntb" | grep -wq "${PLATFORM}"; then
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do
      /bin/set_key_value "${F}" "support_dual_pool" "no"
      /bin/set_key_value "${F}" "partition_curr_version" "9"
    done

    # The installed DSM is one controller of an FSDN pair whose AA cluster
    # stack needs a hardware UUID: SLIBGetSerialNumber(), which on FSDN is the
    # chassis serial that RecordChassisSn.sh stores in
    # /tmp/syno-chassis-serial-number from "synomulticontroller
    # --chassis_sn_get". That reads the chassis EEPROM over I2C, which is not
    # there, so the UUID was empty: synoaa-init, the distributed lock server
    # and everything waiting on an AA lock (nginx among them) never came up.
    # Wrap synomulticontroller so the chassis answers with a serial that
    # belongs to this controller; everything else goes to the real binary.
    # libhwcontrol's SYNOCheckControllerMatchChassis() pairs characters 5-7
    # of the controller serial with those of the chassis serial (R6R-QVR,
    # S4R-S2R, WAR-W8R, WJR-WRR, Y8R-WTR); without a pair AA boots the
    # controller as standby ("bad_hardware") and it never brings up its
    # network. The chassis serial is the controller's with its pair's code.
    SMC="/tmpRoot/usr/syno/bin/synomulticontroller"
    if [ -f "${SMC}" ] && ! grep -q "arc single-controller" "${SMC}" 2>/dev/null; then
      mv -f "${SMC}" "${SMC}.real"
    fi
    cat >"${SMC}" <<'EOF'
#!/bin/sh
# arc single-controller wrapper (epyc7003ntb): no chassis EEPROM, no peer.
SN="$(cat /proc/sys/kernel/syno_serial 2>/dev/null)"
case "$(echo "${SN}" | cut -c5-7)" in
  R6R) C=QVR ;; S4R) C=S2R ;; WAR) C=W8R ;; WJR) C=WRR ;; Y8R) C=WTR ;;
  *) C="$(echo "${SN}" | cut -c5-7)" ;;
esac
CSN="$(echo "${SN}" | cut -c1-4)${C}$(echo "${SN}" | cut -c8-)"
for A in "$@"; do
  case "${A}" in
    --chassis_sn_get)      echo "Chassis Serial Number:${CSN}"; exit 0 ;;
    --check_chassis_match) echo "Controller match this chassis"; exit 0 ;;
  esac
done
exec /usr/syno/bin/synomulticontroller.real "$@"
EOF
    chmod 755 "${SMC}"

    # The controllers talk over NTB as ntb_eth0 (169.254.4.1 controller A,
    # .2 controller B), and DSM Enterprise binds its own services to that
    # address: the session pool's Redis ("bind 127.0.0.1 169.254.4.1"), which
    # synocgid needs to create a session - without it the setup wizard and
    # every sign-in fail. With no NTB there is no ntb_eth0: make one, as a
    # veth pair that never leaves this box (a VLAN on the LAN would put
    # 169.254.4.x on the wire and clash with a second box).
    cat >"/tmpRoot/usr/sbin/arc-ntb-eth0.sh" <<'EOF'
#!/bin/sh
# arc single-controller ntb_eth0 (epyc7003ntb)
IP=169.254.4.1
grep -q '"is_controller0":false' /usr/syno/etc/synoaa/conf/hardware_info 2>/dev/null && IP=169.254.4.2
if ! /sbin/ip link show ntb_eth0 >/dev/null 2>&1; then
  /sbin/modprobe veth 2>/dev/null
  /sbin/ip link add ntb_eth0 type veth peer name ntb_peer0
fi
/sbin/ip addr show ntb_eth0 | grep -q "inet ${IP}/" || /sbin/ip addr add "${IP}/24" dev ntb_eth0
/sbin/ip link set ntb_peer0 up
/sbin/ip link set ntb_eth0 up
exit 0
EOF
    chmod 755 "/tmpRoot/usr/sbin/arc-ntb-eth0.sh"
    cat >"/tmpRoot/usr/lib/systemd/system/arc-ntb-eth0.service" <<'EOF'
[Unit]
Description=arc single-controller ntb_eth0
DefaultDependencies=no
After=syno-kernel-modules-load.service
Before=synoconfstoreeventd.service synoconfstored.service synoaa-init.service synocgid-fsdn-session-redis.service sysinit.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/arc-ntb-eth0.sh

[Install]
WantedBy=sysinit.target
EOF
    mkdir -p "/tmpRoot/usr/lib/systemd/system/sysinit.target.wants"
    ln -sf /usr/lib/systemd/system/arc-ntb-eth0.service "/tmpRoot/usr/lib/systemd/system/sysinit.target.wants/arc-ntb-eth0.service"

    # DSM Enterprise sizes an NVMe drive from "nvme id-ctrl"'s tnvmcap
    # (libsynonvme SYNONVMeCharDevSizeGet), which a drive may leave 0 - QEMU's
    # does, and so do drives that report no capacity there. Storage Manager
    # then shows 0 bytes and offers no drive for a storage pool. Wrap nvme so
    # a 0 tnvmcap (id-ctrl) or nvmcap (id-ns) is the namespaces' real size;
    # every other answer is the real binary's, unchanged.
    # The real binary goes to /usr/syno/bin: DSM's AppArmor profiles (e.g.
    # synostgdisk's) may execute /usr/sbin/nvme and /usr/syno/bin/*, but not
    # /usr/sbin/nvme.real. The wrapper uses shell builtins only, for the same
    # reason.
    NVME="/tmpRoot/usr/sbin/nvme"
    REAL="/tmpRoot/usr/syno/bin/nvme.real"
    [ -f "/tmpRoot/usr/sbin/nvme.real" ] && mv -f "/tmpRoot/usr/sbin/nvme.real" "${REAL}"
    if [ -f "${NVME}" ] && ! grep -q "arc nvme capacity" "${NVME}" 2>/dev/null; then
      mv -f "${NVME}" "${REAL}"
    fi
    if [ -f "${REAL}" ]; then
      cat >"${NVME}" <<'EOF'
#!/bin/sh
# arc nvme capacity wrapper (epyc7003ntb): fill a tnvmcap/nvmcap left at 0.
REAL=/usr/syno/bin/nvme.real
case "$1" in id-ctrl | id-ns) ;; *) exec "${REAL}" "$@" ;; esac
DEV=""; NS=""; P=""
for A in "$@"; do
  case "${A}" in /dev/nvme*) DEV="${A#/dev/nvme}" ;; esac
  [ "${P}" = "-n" ] && NS="${A}"
  case "${A}" in --namespace-id=*) NS="${A#*=}" ;; esac
  P="${A}"
done
OUT="$("${REAL}" "$@")"; RC=$?
CTRL=""
[ -n "${DEV}" ] && CTRL="nvme${DEV%%n*}"
case "${DEV}" in *n*) [ -z "${NS}" ] && NS="${DEV#*n}" ;; esac
T=0
if [ "${RC}" -eq 0 ] && [ -n "${CTRL}" ]; then
  if [ "$1" = "id-ctrl" ]; then
    for B in /sys/block/${CTRL}n*; do
      [ -f "${B}/size" ] && read -r S <"${B}/size" && T=$((T + S * 512))
    done
  elif [ -n "${NS}" ] && [ -f "/sys/block/${CTRL}n${NS}/size" ]; then
    read -r S <"/sys/block/${CTRL}n${NS}/size" && T=$((S * 512))
  fi
fi
[ -n "${OUT}" ] && printf '%s\n' "${OUT}" | while IFS= read -r L; do
  case "${L}" in
    "tnvmcap "*": 0" | "nvmcap "*": 0")
      [ "${T}" -gt 0 ] && L="${L%0}${T}" ;;
  esac
  printf '%s\n' "${L}"
done
exit "${RC}"
EOF
      chmod 755 "${NVME}"
    fi
  fi

  # pci.ids
  mkdir -vp /tmpRoot/usr/local/share
  cp -vpf /usr/local/share/pci.ids.gz /tmpRoot/usr/local/share/pci.ids.gz

  # CPU performance scaling
  mount -t sysfs sysfs /sys
  modprobe acpi-cpufreq
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf ]; then
    CPUFREQ=$(ls -l /sys/devices/system/cpu/cpufreq/*/* 2>/dev/null | wc -l)
    if [ ${CPUFREQ} -eq 0 ]; then
      echo "CPU does NOT support CPU Performance Scaling, disabling"
      sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
    else
      echo "CPU supports CPU Performance Scaling, enabling"
      sed -i 's/^# acpi-cpufreq/acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
      cp -vpf /usr/lib/modules/cpufreq_* /tmpRoot/usr/lib/modules/
    fi
  fi
  modprobe -r acpi-cpufreq
  umount /sys

  # crypto-kernel
  if [ -f /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf ]; then
    # crc32c-intel
    if grep flags /proc/cpuinfo 2>/dev/null | grep -wq sse4_2; then
      echo "CPU Supports SSE4.2, crc32c-intel should load"
      sed -i 's/^# crc32c-intel/crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    else
      echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"
      sed -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi

    # aesni-intel
    if grep flags /proc/cpuinfo 2>/dev/null | grep -wq aes; then
      echo "CPU Supports AES, aesni-intel should load"
      for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_aesni_intel" "yes"; done
      sed -i 's/^# aesni-intel/aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    else
      echo "CPU does NOT support AES, aesni-intel will not load, disabling"
      for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_aesni_intel" "no"; done
      sed -i 's/^aesni-intel/# aesni-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf
    fi
  fi

  # Nvidia GPU
  if grep -iq 10de /proc/bus/pci/devices 2>/dev/null; then
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_nvidia_gpu" "yes"; done
    [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ] && sed -i 's/^# nvidia/nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
  else
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_nvidia_gpu" "no"; done
    [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf ] && sed -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
  fi

  # AMD GPU
  AMDGPU_KO=""
  for K in "/tmpRoot/usr/lib/modules/amdgpu.ko" "/usr/lib/modules/amdgpu.ko"; do
    [ -z "${AMDGPU_KO}" ] && [ -f "${K}" ] && AMDGPU_KO="${K}"
  done

  AMDGPU_DEV=""
  if [ -n "${AMDGPU_KO}" ]; then
    AMDGPU_ALIAS="$(modinfo -F alias "${AMDGPU_KO}" 2>/dev/null)"
    if [ -n "${AMDGPU_ALIAS}" ]; then
      for E in $(lspci -n 2>/dev/null \
        | grep -E ' 03[0-9a-fA-F]{2}: 1002:[0-9a-fA-F]{4}' \
        | awk '{print $2 $3}' | tr -d ':' | tr 'A-F' 'a-f'); do
        CLASS="$(echo "${E}" | cut -c1-4)"
        DEV="$(echo "${E}" | cut -c9-12)"
        if echo "${AMDGPU_ALIAS}" | grep -qi "pci:v00001002d0000${DEV}sv"; then
          AMDGPU_DEV="${DEV}"
          break
        fi
        if echo "${AMDGPU_ALIAS}" | grep -qi "pci:v00001002d[*]sv[*]sd[*]bc$(echo "${CLASS}" | cut -c1-2)sc$(echo "${CLASS}" | cut -c3-4)"; then
          AMDGPU_DEV="${DEV}"
          break
        fi
        echo "amdgpu has no alias matching 1002:${DEV}, not forcing a load"
      done
    fi
  fi

  if [ -n "${AMDGPU_DEV}" ]; then
    echo "AMD GPU 1002:${AMDGPU_DEV} detected, forcing amdgpu to load"
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_amd_gpu" "yes"; done
    mkdir -vp /tmpRoot/usr/lib/modules-load.d
    echo "amdgpu" >/tmpRoot/usr/lib/modules-load.d/70-syno-amdgpu-gpu.conf
  else
    for F in "/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf"; do /bin/set_key_value "${F}" "support_amd_gpu" "no"; done
    [ -f /tmpRoot/usr/lib/modules-load.d/70-syno-amdgpu-gpu.conf ] && rm -f /tmpRoot/usr/lib/modules-load.d/70-syno-amdgpu-gpu.conf
  fi

  # sdcard
  [ ! -f /tmpRoot/usr/lib/udev/script/sdcard.sh.bak ] && cp -vpf /tmpRoot/usr/lib/udev/script/sdcard.sh /tmpRoot/usr/lib/udev/script/sdcard.sh.bak
  printf '#!/bin/sh\nexit 0\n' >/tmpRoot/usr/lib/udev/script/sdcard.sh

  # beep
  cp -vpf /usr/bin/beep /tmpRoot/usr/bin/beep

  # san
  cp -vpdf /usr/lib/libubsan.so* /tmpRoot/usr/lib/

  # arc
  cp -vpf /usr/bin/loader-reboot.sh /tmpRoot/usr/bin/loader-reboot.sh
  cp -vpf /usr/bin/grub-editenv /tmpRoot/usr/bin/grub-editenv
  cp -vpf /usr/bin/jq /tmpRoot/usr/bin/jq

  # SynoInitEth syno-oob-check-status syno_update_disk_logs syno-nic-supported-check syno-switch-check
  mkdir -vp /tmpRoot/usr/lib/systemd/system
  rm -f /tmpRoot/usr/lib/modules-load.d/70-network*.conf
  sed -i 's|^ExecStart=/|ExecStart=-/|g' /tmpRoot/usr/lib/systemd/system/systemd-modules-load.service 2>/dev/null
  sed -i 's|ExecStart=.*|ExecStart=/bin/true|g' /tmpRoot/usr/lib/systemd/system/SynoInitEth.service 2>/dev/null
  sed -i 's|ExecStart=.*|ExecStart=/bin/true|g' /tmpRoot/usr/lib/systemd/system/syno-oob-check-status.service 2>/dev/null
  sed -i 's|ExecStart=.*|ExecStart=/bin/true|g' /tmpRoot/usr/lib/systemd/system/syno_update_disk_logs.service 2>/dev/null

  # getty
  for I in $(cat /proc/cmdline 2>/dev/null | grep -Eo 'getty=[^ ]+' | sed 's/getty=//'); do
    TTYN="$(echo "${I}" | cut -d',' -f1)"
    BAUD="$(echo "${I}" | cut -d',' -f2 | cut -d'n' -f1)"
    echo "ttyS0 ttyS1 ttyS2" | grep -wq "${TTYN}" && continue

    mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
    if [ -n "${TTYN}" ] && [ -e "/dev/${TTYN}" ]; then
      echo "Make getty\@${TTYN}.service"
      cp -vpf /tmpRoot/usr/lib/systemd/system/serial-getty\@.service /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      sed -i "s|^ExecStart=.*|ExecStart=/sbin/agetty %I ${BAUD:-115200} linux|" /tmpRoot/usr/lib/systemd/system/getty\@${TTYN}.service
      mkdir -vp /tmpRoot/usr/lib/systemd/system/getty.target.wants
      ln -vsf /usr/lib/systemd/system/getty\@${TTYN}.service /tmpRoot/usr/lib/systemd/system/getty.target.wants/getty\@${TTYN}.service
    fi
  done

  # cleanup
  [ -f /tmpRoot/usr/sbin/arccontrol.sh ] && rm -f /tmpRoot/usr/sbin/arccontrol.sh 2>/dev/null
  [ -f /tmpRoot/usr/lib/systemd/system/arccontrol.service ] && rm -f /tmpRoot/usr/lib/systemd/system/arccontrol.service 2>/dev/null

  # arc-misc
  cp -vpf /usr/bin/arc-misc.sh /tmpRoot/usr/bin/arc-misc.sh

  DEST="/tmpRoot/usr/lib/systemd/system/arc-misc.service"
  {
    echo "[Unit]"
    echo "Description=arc-misc daemon"
    echo "After=multi-user.target"
    echo "After=scemd.service rc-network.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/arc-misc.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-misc.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-misc.service

  # arc-once
  cp -vpf /usr/bin/arc-once.sh /tmpRoot/usr/bin/arc-once.sh

  DEST="/tmpRoot/usr/lib/systemd/system/arc-once.service"
  {
    echo "[Unit]"
    echo "Description=arc-once daemon"
    echo "After=multi-user.target"
    echo "After=scemd.service rc-network.service"
    echo "After=synoscgi.service nginx.service syno-mkcert.service"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/arc-once.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/arc-once.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/arc-once.service

  # wol
  cp -pf /usr/bin/wol.sh /tmpRoot/usr/bin/wol.sh

  DEST="/tmpRoot/usr/lib/systemd/system/wol.service"
  {
    echo "[Unit]"
    echo "Description=Force WOL on ethN"
    echo "After=multi-user.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/wol.sh"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"

  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/wol.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/wol.service
fi