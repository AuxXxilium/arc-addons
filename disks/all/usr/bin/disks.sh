#!/usr/bin/env sh
#
# Copyright (C) 2026 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

ROOT_PATH=""
GKV=$([ -x "/usr/syno/bin/synogetkeyvalue" ] && echo "/usr/syno/bin/synogetkeyvalue" || echo "/bin/get_key_value")
SKV=$([ -x "/usr/syno/bin/synosetkeyvalue" ] && echo "/usr/syno/bin/synosetkeyvalue" || echo "/bin/set_key_value")

_log() {
  echo "disks: $*"
  /bin/logger -p "error" -t "disks" "$@"
}

__get_conf_kv() {
  "${GKV}" "${ROOT_PATH}/etc.defaults/synoinfo.conf" "${1}" 2>/dev/null
}

__set_conf_kv() {
  for F in "${ROOT_PATH}/etc/synoinfo.conf" "${ROOT_PATH}/etc.defaults/synoinfo.conf"; do "${SKV}" "${F}" "${1}" "${2}"; done
}

_check_user_conf() {
  [ -f "/addons/synoinfo.conf" ] && UCONF="/addons/synoinfo.conf" || UCONF="/usr/arc/addons/synoinfo.conf"
  grep -Eq "^${1}=" "${UCONF}" 2>/dev/null
}

# True when any disk controller is present: SCSI (0100), RAID (0104), AHCI (0106),
# SAS (0107) or NVMe (0108). Gates the settle wait only - a machine with none of
# these has no disks to wait for.
_has_storage_controller() {
  lspci -n 2>/dev/null | grep -qE ' (0100|0104|0106|0107|0108):'
}

# PCI addresses along a PHYSDEVPATH, root side first, one per line.
_physdev_bdfs() {
  printf '%s' "${1}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]'
}

# Build a device's pciepath from its PHYSDEVPATH, in the shape syno_block_info
# reports and pcie_root carries: the first PCI hop as a full address, then
# dev.fn for every hop below it.
#
#   /devices/pci0000:00/0000:00:1e.0/0000:01:01.0/0000:02:07.0/ata1/...
#   -> 0000:00:1e.0,01.0,07.0
#
# The fallbacks used to take the last address alone. That is the controller's
# own address, which equals the pciepath only for a controller sitting directly
# on the root bus - behind any bridge (every add-in card, most M.2 slots) it
# names a slot that does not exist.
_physdev_pciepath() {
  _physdev_bdfs "${1}" | awk 'NR == 1 { p = $0; next } { sub(/^[0-9a-f]+:[0-9a-f]+:/, ""); p = p "," $0 } END { if (p != "") print p }'
}

# Domain-prefix a pciepath. The dts is assembled in this one spelling so the
# dedup greps compare like with like; syno_block_info may report either
# ("00:17.0" on 4.x). The spelling the running kernel wants is applied once, at
# the end of dtModel. Without this, two namespaces on one NVMe controller could
# resolve to different spellings, both get a slot, and the final sed would turn
# them into the same pcie_root - a phantom bay that never populates.
_pc_norm() {
  case "${1}" in
    '' | [0-9a-f][0-9a-f][0-9a-f][0-9a-f]:*) echo "${1}" ;;
    *) echo "0000:${1}" ;;
  esac
}

# Read a disk's slot identity from /sys/block/<disk>:
#
#   _PP   PHYSDEVPATH
#   _PC   pciepath, domain-prefixed - syno_block_info, else built from _PP
#   _AT   ata_port_no as syno_block_info reports it (may be empty)
#   _DR   driver - syno_block_info, else the one bound to the controller
#   _BDF  the controller's own PCI address
#
# _BDF is what /sys/bus/pci/devices is keyed on. A pciepath behind a bridge
# ("0000:00:01.0,00.0") is not a sysfs name, so class and driver lookups done
# with it came back empty for every add-in controller.
_disk_info() {
  _PP="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${1}/uevent" 2>/dev/null)"
  _SBI="$(cat "${1}/device/syno_block_info" 2>/dev/null)"
  _PC="$(printf '%s\n' "${_SBI}" | sed -n 's/^pciepath=//p')"
  _AT="$(printf '%s\n' "${_SBI}" | sed -n 's/^ata_port_no=//p')"
  _DR="$(printf '%s\n' "${_SBI}" | sed -n 's/^driver=//p')"
  [ -n "${_PC}" ] || _PC="$(_physdev_pciepath "${_PP}")"
  _PC="$(_pc_norm "${_PC}")"
  _BDF="$(_physdev_bdfs "${_PP}" | tail -1)"
  if [ -z "${_BDF}" ]; then
    case "${_PC}" in *,*) : ;; *) _BDF="${_PC}" ;; esac
  fi
  if [ -z "${_DR}" ] && [ -n "${_BDF}" ] && [ -L "/sys/bus/pci/devices/${_BDF}/driver" ]; then
    _DR="$(basename "$(readlink -f "/sys/bus/pci/devices/${_BDF}/driver")")"
  fi
}

_count_disks() {
  C=0
  for _F in ${1}; do [ -e "${_F}" ] && C=$((C + 1)); done
  echo "${C}"
}

# Wait until the number of disk nodes matching the given globs stops changing.
#
# Every controller type needs this, not only HBAs: SATA disks arrive late too
# (staggered spin-up, port multipliers, many-port cards like JMB585/ASM1166),
# and so does NVMe. A disk that lands after dtModel() has run gets no bay, so
# its udev event in DSM misses in dtUpdate() and forces a rebuild and slot
# remap mid-boot.
#
# Runs at most once per process: dtModel() can be re-entered from dtUpdate().
_wait_disks_stable() {
  [ "${_DISKS_WAIT_DONE:-0}" = "1" ] && return 0
  _DISKS_WAIT_DONE=1

  if ! _has_storage_controller; then
    _log "no storage controller found, skipping disk settle wait"
    return 0
  fi

  _wd_globs="${*:-/sys/block/sd*}"

  _wd_count() {
    _C=0
    for _G in ${_wd_globs}; do _C=$((_C + $(_count_disks "${_G}"))); done
    echo "${_C}"
  }

  # This runs in the "patches" boot phase, before DSM userspace comes up, so
  # every second spent here is a second the login screen is not shown. Two
  # things keep that cost down:
  #   - the short-circuit below: if udev already enumerated everything before
  #     we got here (the common case), the count never moves and we leave
  #     after the first two rounds instead of waiting out three stable ones;
  #   - a 60s ceiling, which still covers staggered backplane spin-up but no
  #     longer lets a genuinely stuck controller hold the WebUI for 5 minutes.
  START_COUNT="$(_wd_count)"
  PREV_COUNT="${START_COUNT}"
  STABLE_ROUNDS=0
  I=0
  while [ "${I}" -lt 20 ]; do
    sleep 3
    I=$((I + 1))
    CUR_COUNT="$(_wd_count)"
    if [ "${CUR_COUNT}" = "${PREV_COUNT}" ]; then
      STABLE_ROUNDS=$((STABLE_ROUNDS + 1))
      [ "${STABLE_ROUNDS}" -ge 3 ] && break
      # Nothing has appeared since we started: udev was already done before
      # this ran, so there is no spin-up in progress to wait out.
      [ "${I}" -ge 2 ] && [ "${CUR_COUNT}" = "${START_COUNT}" ] && break
    else
      STABLE_ROUNDS=0
      PREV_COUNT="${CUR_COUNT}"
    fi
  done
  if [ "${I}" -ge 20 ]; then
    _log "disk settle wait timed out after ${I} round(s): [${_wd_globs}] at count ${CUR_COUNT}"
  else
    _log "disks settled after ${I} round(s): [${_wd_globs}] at count ${CUR_COUNT}"
  fi
}

# Decide, once per boot, whether phy_identifier or bay_identifier is the usable
# key for SAS disks - see _sas_bay_index for what each one is.
#
# Neither attribute is globally unique. Both are per-enclosure, so with two
# expanders on one HBA, expander A phy 3 and expander B phy 3 both exist, and a
# JBOD pair can likewise report bay 3 twice. Whichever key collides would send
# two disks to one ata_port; _claim_slot_port then relocates the loser, so no
# disk is lost, but the relocated one is no longer pinned to its wiring - which
# is the entire point of preferring these attributes.
#
# So rather than committing to phy per disk, survey every SAS disk first and
# take phy only if it separates all of them. The survey is over the whole
# controller set at once, which is what makes it able to see a duplicate that a
# per-disk lookup cannot. Falls back to bay on a phy collision, and to neither
# (leaving the driver's ata_port_no in place) when both collide.
#
# Sets _SAS_KEY to "phy", "bay" or "" and is idempotent per run.
_sas_pick_key() {
  [ -n "${_SAS_KEY_DONE:-}" ] && return 0
  _SAS_KEY_DONE=1
  _SAS_KEY=""

  _SPK_PHY=""
  _SPK_BAY=""
  _SPK_N=0
  for _SPK_D in /sys/class/sas_device/end_device-*; do
    [ -d "${_SPK_D}" ] || continue
    _SPK_N=$((_SPK_N + 1))
    _SPK_P="$(cat "${_SPK_D}/phy_identifier" 2>/dev/null)"
    case "${_SPK_P}" in '' | *[!0-9]*) _SPK_P="x" ;; esac
    _SPK_B="$(cat "${_SPK_D}/bay_identifier" 2>/dev/null)"
    case "${_SPK_B}" in '' | *[!0-9]*) _SPK_B="x" ;; esac
    _SPK_PHY="${_SPK_PHY} ${_SPK_P}"
    _SPK_BAY="${_SPK_BAY} ${_SPK_B}"
  done
  [ "${_SPK_N}" -gt 0 ] || return 0

  # Usable means: every disk has a numeric value AND no two share one.
  _spk_ok() {
    case " ${1} " in *" x "*) return 1 ;; esac
    [ "$(printf '%s\n' ${1} | sort -n | uniq | wc -l)" -eq "${_SPK_N}" ]
  }

  if _spk_ok "${_SPK_PHY}"; then
    _SAS_KEY="phy"
  elif _spk_ok "${_SPK_BAY}"; then
    _SAS_KEY="bay"
    _log "sas: phy_identifier is not unique across ${_SPK_N} disk(s), keying bays on bay_identifier"
  else
    _log "sas: neither phy_identifier nor bay_identifier separates ${_SPK_N} disk(s), keeping driver ata_port_no"
  fi
}

# Derive a boot-stable bay index for a disk on a SAS HBA, or nothing.
#
# Everything the SCSI layer offers to identify a disk is an enumeration
# artefact: the target id, the port-H:P transport node number and the firmware
# handle are all assigned as devices are discovered, so a rescan, a staggered
# spin-up or a replaced drive can renumber them. On a SAS controller every disk
# shares the controller's pciepath, so ata_port is the only thing separating
# dtModel()'s internal_slot nodes - and DSM caches the bay<->disk association.
# An index that moves between boots therefore silently reassigns bays.
#
# Two attributes are properties of the wiring rather than of discovery order:
#
#   1. phy_identifier - the phy the drive is wired to. For direct-attach this
#      is the HBA phy and is fixed by the cable; behind an expander it is the
#      expander phy, fixed by the backplane connector.
#   2. bay_identifier - the SES/SGPIO slot the enclosure reports, the same
#      number dmesg prints as "enclosure logical id(...), slot(N)".
#
# Which of the two is used is decided once per run by _sas_pick_key, not per
# disk: neither is globally unique, so preferring phy disk-by-disk would key
# two disks behind different expanders to the same port even when bay would
# have separated them cleanly. The survey there picks whichever attribute
# actually distinguishes every SAS disk present.
#
# _sas_pick_key must have been called by the caller BEFORE this runs. This is
# invoked as "$(_sas_bay_index ...)", so anything it logs would be captured as
# part of the index, and any variable it set would be lost with the subshell -
# the same trap documented on _claim_slot_port.
#
# Echoes nothing when no attribute was usable, so the caller keeps whatever the
# driver reported.
_sas_bay_index() {
  _SBI_PP="${1}"
  [ -n "${_SBI_PP}" ] || return 0

  [ -n "${_SAS_KEY}" ] || return 0

  _SBI_ED="$(printf '%s' "${_SBI_PP}" | grep -Eo 'end_device-[0-9]+:[0-9]+(:[0-9]+)?' | tail -1)"
  [ -n "${_SBI_ED}" ] || return 0

  _SBI_D="/sys/class/sas_device/${_SBI_ED}"
  [ -d "${_SBI_D}" ] || return 0

  # _sas_pick_key has already established that this attribute is numeric and
  # unique for every SAS disk present, so no further validation is needed here
  # beyond rejecting a read that fails outright.
  _SBI_V="$(cat "${_SBI_D}/${_SAS_KEY}_identifier" 2>/dev/null)"
  case "${_SBI_V}" in
    '' | *[!0-9]*) return 0 ;;
  esac
  echo "${_SBI_V}"
}

# Derive a per-controller unique port index for a disk whose syno_block_info
# carries no usable ata_port_no.
#
# Why this is needed: on a SAS HBA every disk shares one pciepath (the
# controller's own BDF), so dtModel()'s internal_slot nodes are distinguished
# by ata_port alone. arc-lkm's sata_port_shim synthesizes that index, but only
# when it is the one filling syno_block_info - on 5.10 the vendor driver's own
# populator (syno_mptNsas_info_enum and friends) runs first and the shim stands
# down, and those populators can leave ata_port_no empty or zero for every
# disk. dtModel() then emitted twelve slots all claiming port 0, which
# syno_slot_mapping collapses into a single bay: every disk shows as "Disk 1".
#
# The chain below follows arc-lkm's fallback order (sata_port_shim.c):
#   1. port-H:P topology node   (SAS HBAs - P is the per-controller port)
#   2. SCSI target id           (several targets behind one host - HBA fan-out)
#   3. SCSI host number         (one host per disk - the VirtIO case)
# with one deliberate difference at step 1. arc-lkm scans with
# sscanf("port-%u:%u"), which stops after two fields; walking up from the disk
# it meets the expander-side node first, so every disk behind one expander phy
# reads back as the same port. Taking the LAST field of the longest port- node
# keeps those distinct. The values therefore differ from the LKM's only on
# expander topologies, where the LKM's would collide anyway - and only one of
# the two ever fills syno_block_info for a given disk, so they are never
# combined for one bay.
#
# Echoes nothing when no component can be resolved, so callers can tell
# "no index" apart from "port 0". Any collision that survives is caught by
# _claim_slot_port, so a wrong-but-unique index still yields a working bay.
_hba_port_index() {
  _HPI_PP="${1}"
  [ -n "${_HPI_PP}" ] || return 0

  # 1. .../port-30:4/end_device-30:4/target30:0:4/30:0:4:0 -> 4
  #    Behind an expander the node is port-H:E:P (port-0:0:11 -> 11), so match
  #    the longest form first and always take the last field.
  _HPI_V="$(printf '%s' "${_HPI_PP}" | grep -Eo 'port-[0-9]+(:[0-9]+)+' | tail -1 | sed 's/.*://')"
  if [ -n "${_HPI_V}" ]; then echo "${_HPI_V}"; return 0; fi

  # 2/3. trailing H:C:T:L. Target id normally varies per disk behind one host
  # (HBA fan-out) and is the right index - including target 0, which is a real
  # bay, not a missing value. The exception is a controller that gives each
  # disk its own host with target 0 (VirtIO): there every disk would report
  # target 0, so the host number is what actually distinguishes them. Tell the
  # two apart by counting the targets under this host rather than by treating
  # target 0 as invalid, which would alias target 0 onto host N's index.
  _HPI_HCTL="$(printf '%s' "${_HPI_PP}" | grep -Eo '[0-9]+:[0-9]+:[0-9]+:[0-9]+$' | tail -1)"
  if [ -n "${_HPI_HCTL}" ]; then
    _HPI_H="$(printf '%s' "${_HPI_HCTL}" | cut -d':' -f1)"
    _HPI_T="$(printf '%s' "${_HPI_HCTL}" | cut -d':' -f3)"
    if [ "${_HPI_T}" = "0" ] && [ -n "${_HPI_H}" ]; then
      _HPI_NT=0
      for _HPI_E in /sys/class/scsi_device/${_HPI_H}:*:*:*; do
        [ -e "${_HPI_E}" ] && _HPI_NT=$((_HPI_NT + 1))
      done
      # Exactly one device on this host: the host number is the only component
      # that varies between disks, so use it (the VirtIO case). A count of 0
      # means the enumeration itself failed, not that the host is empty - keep
      # the target id then, since guessing the host number here would alias
      # target 0 onto whatever disk legitimately sits at target <host>.
      [ "${_HPI_NT}" -eq 1 ] && { echo "${_HPI_H}"; return 0; }
    fi
    if [ -n "${_HPI_T}" ]; then echo "${_HPI_T}"; return 0; fi
    if [ -n "${_HPI_H}" ]; then echo "${_HPI_H}"; return 0; fi
  fi

  return 0
}

# Claim (pciepath, ata_port) for one slot, or move the disk to the next free
# port on that controller. Two disks sharing a pair collapse into one DSM bay,
# which is the whole failure being fixed here, so a collision must be resolved
# rather than emitted.
#
# The claimed port is returned in _SLOT_PORT, NOT on stdout: the claim list has
# to persist across calls, and "$(_claim_slot_port ...)" would run this in a
# subshell where every update to _CLAIMED_SLOTS is discarded - every disk would
# then see an empty list, find port 0 free, and collide exactly as before.
# Returns 1 (leaving _SLOT_PORT empty) when no free port could be found.
_claim_slot_port() {
  _CSP_PC="${1}"
  _CSP_AT="${2}"
  _SLOT_PORT=""

  case " ${_CLAIMED_SLOTS} " in
    *" ${_CSP_PC}|${_CSP_AT} "*) : ;;
    *)
      _CLAIMED_SLOTS="${_CLAIMED_SLOTS:+${_CLAIMED_SLOTS} }${_CSP_PC}|${_CSP_AT}"
      _SLOT_PORT="${_CSP_AT}"
      return 0
      ;;
  esac

  # Taken: walk upward for the first free port on this controller. 64 covers
  # the 26-disk ceiling dtModel() enforces via maxdisks with room to spare.
  _CSP_N="${_CSP_AT}"
  _CSP_TRY=0
  while [ "${_CSP_TRY}" -lt 64 ]; do
    _CSP_N=$((_CSP_N + 1))
    _CSP_TRY=$((_CSP_TRY + 1))
    case " ${_CLAIMED_SLOTS} " in
      *" ${_CSP_PC}|${_CSP_N} "*) continue ;;
    esac
    _CLAIMED_SLOTS="${_CLAIMED_SLOTS:+${_CLAIMED_SLOTS} }${_CSP_PC}|${_CSP_N}"
    _log "ata_port collision on ${_CSP_PC}: port ${_CSP_AT} taken, using ${_CSP_N}"
    _SLOT_PORT="${_CSP_N}"
    return 0
  done

  _log "ata_port collision on ${_CSP_PC}: no free port near ${_CSP_AT}"
  return 1
}

_atoi() {
  DISKNAME=${1}
  NUM=0
  IDX=0
  while [ ${IDX} -lt ${#DISKNAME} ]; do
    N=$(($(printf '%d' "'$(expr substr "${DISKNAME}" $((IDX + 1)) 1)") - $(printf '%d' "'a") + 1))
    BIT=$(($(expr length "${DISKNAME}") - 1 - IDX))
    # shellcheck disable=SC3019
    NUM=$((NUM + (BIT == 0 ? N : 26 ** BIT * N)))
    IDX=$((IDX + 1))
  done
  echo $((NUM - 1))
}

_check_rootraidstatus() {
  [ "$(__get_conf_kv supportraid)" = "yes" ] || return 1
  [ -f "/sys/block/md0/md/array_state" ] || return 1
  STATE=$(cat "/sys/block/md0/md/array_state" 2>/dev/null)
  case ${STATE} in
    "clear" | "inactive" | "suspended" | "readonly" | "read-auto") return 1 ;;
  esac
  return 0
}

_itol() {
  IFS="${IFS:- }"
  NUM="$(echo $((${1:-"-1"})))"
  IDX=0
  DISKLIST=""
  while [ ${NUM} -gt 0 ]; do
    if [ "$((NUM & 1))" = 1 ]; then
      case $((IDX / 26)) in
        0) dev="$(printf sd\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;;
        *) dev="$(printf sd\\x"$(printf "%x" "$((IDX / 26 - 1 + $(printf '%d' "'a")))")"\\x"$(printf "%x" "$((IDX % 26 + $(printf '%d' "'a")))")")" ;;
      esac
      DISKLIST="${DISKLIST:+${DISKLIST}${IFS}}${dev}"
    fi
    NUM=$((NUM >> 1))
    IDX=$((IDX + 1))
  done
  echo "${DISKLIST}"
}

checkAlldisk() {
  for F in $(LC_ALL=C printf '%s\n' /sys/block/* | sort -V); do
    [ ! -e "${F}" ] && continue
    N="$(basename "${F}" 2>/dev/null)"

    if [ ! -b "/dev/${N}" ] && [ -d "/sys/block/${N}" ]; then
      MAJOR="$(cat "/sys/block/${N}/dev" | cut -d':' -f1)"
      MINOR="$(cat "/sys/block/${N}/dev" | cut -d':' -f2)"
      mknod "/dev/${N}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
    fi
    for i in 1 2 3 p1 p2 p3; do
      if [ ! -b "/dev/${N}${i}" ] && [ -d "/sys/block/${N}/${N}${i}" ]; then
        MAJOR="$(cat "/sys/block/${N}/${N}${i}/dev" | cut -d':' -f1)"
        MINOR="$(cat "/sys/block/${N}/${N}${i}/dev" | cut -d':' -f2)"
        mknod "/dev/${N}${i}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
      fi
    done
  done

}

checkSynoboot() {
  if [ ! -b /dev/synoboot ] || [ ! -b /dev/synoboot1 ] || [ ! -b /dev/synoboot2 ] || [ ! -b /dev/synoboot3 ]; then
    [ -z "${BOOTDISK}" ] && return
    if [ ! -b "/dev/synoboot" ] && [ -d "/sys/block/${BOOTDISK}" ]; then
      MAJOR="$(cat "/sys/block/${BOOTDISK}/dev" | cut -d':' -f1)"
      MINOR="$(cat "/sys/block/${BOOTDISK}/dev" | cut -d':' -f2)"
      mknod "/dev/synoboot" b ${MAJOR} ${MINOR} >/dev/null 2>&1
      rm -vf "/dev/${BOOTDISK}"
    fi
    for i in 1 2 3 p1 p2 p3; do
      n=$(echo "${i}" | sed 's/p//')
      if [ ! -b "/dev/synoboot${n}" ] && [ -d "/sys/block/${BOOTDISK}/${BOOTDISK}${i}" ]; then
        MAJOR="$(cat "/sys/block/${BOOTDISK}/${BOOTDISK}${i}/dev" | cut -d':' -f1)"
        MINOR="$(cat "/sys/block/${BOOTDISK}/${BOOTDISK}${i}/dev" | cut -d':' -f2)"
        mknod "/dev/synoboot${n}" b ${MAJOR} ${MINOR} >/dev/null 2>&1
        rm -vf "/dev/${BOOTDISK}${i}"
      fi
    done
  fi
}

getUsbPorts() {
  for F in $(LC_ALL=C printf '%s\n' /sys/bus/usb/devices/usb* | sort -V); do
    [ ! -e "${F}" ] && continue
    RCHILDS=0
    RBUS=0
    HAVE_CHILD=0
    [ ! "$(cat "${F}/bDeviceClass" 2>/dev/null)" = "09" ] && continue
    [ "$(cat "${F}/speed" 2>/dev/null)" -lt 480 ] && continue
    RCHILDS=$(cat ${F}/maxchild 2>/dev/null)
    RBUS=$(cat "${F}/busnum" 2>/dev/null)
    for C in $(seq 1 ${RCHILDS:-0}); do
      if [ -d "${F}/${RBUS:-0}-${C}" ]; then
        [ ! "$(cat "${F}/${RBUS:-0}-${C}/bDeviceClass" 2>/dev/null)" = "09" ] && continue
        [ "$(cat "${F}/${RBUS:-0}-${C}/speed" 2>/dev/null)" -lt 480 ] && continue
        HAVE_CHILD=1
        CHILDS=$(cat "${F}/${RBUS:-0}-${C}/maxchild" 2>/dev/null)
        for N in $(seq 1 ${CHILDS:-0}); do printf "${RBUS:-0}-${C}.${N} "; done
      fi
    done
    [ ${HAVE_CHILD} -eq 0 ] && for N in $(seq 1 ${RCHILDS:-0}); do printf "${RBUS:-0}-${N} "; done
  done
  echo
}

# Append one internal_slot for a SATA/HBA disk: $1 pcie_root, $2 driver,
# $3 ata_port. Also records the driver name its controller was first emitted
# with - every slot on one controller has to carry the same one, see the sd*
# pass in dtModel.
_emit_sata_slot() {
  case " ${_CTRL_DRIVERS} " in
    *" ${1}|"*) : ;;
    *) _CTRL_DRIVERS="${_CTRL_DRIVERS:+${_CTRL_DRIVERS} }${1}|${2}" ;;
  esac
  COUNT=$((COUNT + 1))
  {
    echo "    internal_slot@${COUNT} {"
    echo '        protocol_type = "sata";'
    echo "        ${2} {"
    echo "            pcie_root = \"${1}\";"
    printf "            ata_port = <0x%02X>;\n" "${3}"
    echo "            internal_mode;"
    echo "        };"
    echo "    };"
  } >>"${DEST}"
}

dtModel() {
  _log dtModel

  UNIQUE=$(__get_conf_kv unique)

  _wait_disks_stable "/sys/block/sata* /sys/block/sd* /sys/block/nvme*"

  DEST="/etc/model.dts"
  # A user-supplied dts has two homes and both have to be consulted.
  #
  # /addons/model.dts only exists inside the ramdisk: install.sh's late stage
  # persists it to /etc/user_model.dts precisely so it survives into the booted
  # rootfs. Reading only /addons meant that once DSM was up the upload was gone
  # - any later regeneration (a --create after an upgrade, a lost model.dtb)
  # auto-generated over it and the custom slots silently reverted.
  # /addons wins when both are present: it is the fresher upload.
  USER_DTS=""
  [ -f "/etc/user_model.dts" ] && USER_DTS="/etc/user_model.dts"
  [ -f "/addons/model.dts" ] && USER_DTS="/addons/model.dts"
  [ -n "${USER_DTS}" ] && { cp -vpf "${USER_DTS}" "${DEST}"; _log "using user dts: ${USER_DTS}"; }
  if [ ! -f "${DEST}" ]; then
    mkdir -p "$(dirname "${DEST}" 2>/dev/null)"
    {
      echo "/dts-v1/;"
      echo "/ {"
      echo '    compatible = "Synology";'
      echo '    model = "";'
      echo "    version = <0x01>;"
      echo "    #address-cells = <1>;"
      echo "    #size-cells = <0>;"
      echo '    power_limit = "";'
    } >"${DEST}"

    COUNT=0
    # Reset per run: dtModel can be re-entered from dtUpdate, and a stale claim
    # list would push every disk of the second run onto shifted ports.
    _CLAIMED_SLOTS=""
    _SEEN_PHYSDEV=""
    _CTRL_DRIVERS=""

    # Survey the SAS attributes once, here in the function's own shell: both
    # loops below call _sas_bay_index from inside "$(...)", where neither the
    # cached choice nor its log line would survive.
    _sas_pick_key

    for _F in $(LC_ALL=C printf '%s\n' /sys/block/sata* | sort -V); do
      [ -e "${_F}" ] || continue
      _N="$(basename "${_F}")"
      [ -n "${BOOTDISK}" ] && [ "${_N}" = "${BOOTDISK}" ] && { _log "bootloader: ${_F}"; continue; }
      _disk_info "${_F}"
      [ -n "${_PC}" ] || { _log "unknown: ${_F}"; continue; }
      [ -n "${_DR}" ] || { _log "unknown driver: ${_F}"; continue; }
      if [ -z "${_AT}" ] && [ -n "${_PP}" ]; then
        _FB_ATA="$(printf '%s' "${_PP}" | grep -Eo 'ata[0-9]+' | head -1)"
        _FB_CTRL="/sys${_PP%%/ata*}"
        if [ -n "${_FB_ATA}" ] && [ -d "${_FB_CTRL}" ]; then
          _FB_IDX=0
          for _FB_E in $(ls "${_FB_CTRL}" 2>/dev/null | grep '^ata[0-9]' | sort -V); do
            [ "${_FB_E}" = "${_FB_ATA}" ] && { _AT=${_FB_IDX}; break; }
            _FB_IDX=$((_FB_IDX + 1))
          done
        fi
        # No ataN component in the path: not a libata topology. A SAS HBA looks
        # like .../port-30:4/end_device-30:4/target30:0:4/30:0:4:0, so fall back
        # to the SAS/SCSI chain rather than letting an empty _AT print as port 0.
        [ -z "${_AT}" ] && _AT="$(_hba_port_index "${_PP}")"
      fi
      # Guard the printf below: "%02X" on an empty or non-numeric _AT yields
      # 0x00, which is how a whole HBA's worth of disks ended up sharing one bay.
      case "${_AT}" in
        '' | *[!0-9]*) _log "unusable ata_port_no for ${_F} [${_AT:-empty}]"; _AT="" ;;
      esac
      # The wiring outranks whatever the driver reported. On 5.10 the vendor
      # populator (syno_mptNsas_info_enum) derives ata_port_no from discovery
      # order, which is not stable across boots - see _sas_bay_index.
      _SB="$(_sas_bay_index "${_PP}")"
      if [ -n "${_SB}" ] && [ "${_SB}" != "${_AT}" ]; then
        _log "sas bay for ${_F}: ata_port_no=${_AT:-empty} -> ${_SB}"
        _AT="${_SB}"
      fi
      if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${_PP}" ] && [ "${_PP}" = "${BOOTDISK_PHYSDEVPATH}" ]; then
        _log "bootloader (alias): ${_F}"; continue
      fi
      if [ "${BOOTDISK_PCIEPATH}" = "${_PC}" ] && [ -n "${BOOTDISK_ATAPORT}" ] && [ "${BOOTDISK_ATAPORT}" = "${_AT}" ]; then
        _log "bootloader (port ${_AT}): ${_F}"; continue
      fi
      # An unresolved _AT starts the search at port 0 rather than being emitted
      # as one, so the disk still gets a bay of its own.
      _claim_slot_port "${_PC}" "${_AT:-0}" || { _log "no slot for ${_F}"; continue; }
      _AT="${_SLOT_PORT}"
      # Record the final bay for every disk, not just the sd* pass below: a bay
      # that moves between boots is only visible by comparing these across two
      # logs, and this loop previously emitted nothing at all.
      _log "slot: ${_F} -> ${_PC} port ${_AT} (${_DR})"
      [ -n "${_PP}" ] && _SEEN_PHYSDEV="${_SEEN_PHYSDEV:+${_SEEN_PHYSDEV} }${_PP}"
      _emit_sata_slot "${_PC}" "${_DR}" "${_AT}"
    done

    # Second pass: HBA disks that never became sataN.
    #
    # arc-lkm's sata_port_shim forces syno_port_type to SATA for SAS/VirtIO
    # hosts so sd.c names them sataN and the loop above picks them up. That fix
    # can miss - the vendor driver already populated syno_block_info, the
    # replug did not re-probe, or the host template was not matched - leaving
    # the disks as plain sdN with no slot at all, and DSM with no bay for them.
    # Emit those here rather than losing them. USB and the loader are excluded.
    #
    # A disk is named either sataN or sdX, never both, so the two globs cannot
    # normally return the same device - but _SEEN_PHYSDEV is checked anyway:
    # emitting one disk twice would inflate the internal_slot@ count that sets
    # maxdisks below, and a maxdisks that disagrees with the real slot count is
    # exactly the class of mismatch that has caused boot failures before.
    for _F in $(LC_ALL=C printf '%s\n' /sys/block/sd* | sort -V); do
      [ -e "${_F}" ] || continue
      _N="$(basename "${_F}")"
      [ -n "${BOOTDISK}" ] && [ "${_N}" = "${BOOTDISK}" ] && { _log "bootloader: ${_F}"; continue; }
      _disk_info "${_F}"
      case "${_PP}" in *usb*) continue ;; esac
      if [ -n "${_PP}" ]; then
        case " ${_SEEN_PHYSDEV} " in
          *" ${_PP} "*) _log "already slotted: ${_F}"; continue ;;
        esac
      fi
      if [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${_PP}" ] && [ "${_PP}" = "${BOOTDISK_PHYSDEVPATH}" ]; then
        _log "bootloader (alias): ${_F}"; continue
      fi
      [ -n "${_PC}" ] || { _log "unknown: ${_F}"; continue; }
      # Only PCI storage controllers (class 01xx) own internal bays here. Looked
      # up by the controller's own address: a pciepath with bridge hops is not
      # a sysfs name, so every add-in HBA read back as "not a storage controller".
      _CL="$(cat "/sys/bus/pci/devices/${_BDF}/class" 2>/dev/null)"
      case "${_CL}" in 0x01*) : ;; *) _log "not a storage controller: ${_F} [${_CL:-unknown}]"; continue ;; esac
      # Slot nodes are keyed by driver name, and every slot on one controller
      # must use the same one - a dts that describes 0000:50:00.0 as both
      # "ahci" and "mpt3sas" presents it to DSM as two different controllers.
      # Pass 1 emits whatever syno_block_info reported, so reuse that name here
      # instead of re-deriving it; a disk with an empty syno_block_info (the
      # very reason it landed in this pass) would otherwise fall back to a
      # different name than its neighbours. Only when this controller has no
      # slot yet at all does the fallback apply: "ahci", which is what arc-lkm
      # reports for synthetic HBA entries (sata_port_shim.c) and the one name
      # DSM always accepts.
      _P1_DR=""
      for _P1_E in ${_CTRL_DRIVERS}; do
        case "${_P1_E}" in "${_PC}|"*) _P1_DR="${_P1_E#*|}"; break ;; esac
      done
      [ -n "${_P1_DR}" ] && _DR="${_P1_DR}"
      [ -z "${_DR}" ] && _DR="ahci"
      case "${_AT}" in
        '' | *[!0-9]*) _AT="$(_hba_port_index "${_PP}")" ;;
      esac
      # As in pass 1: prefer the wiring over the enumeration-order index.
      _SB="$(_sas_bay_index "${_PP}")"
      if [ -n "${_SB}" ] && [ "${_SB}" != "${_AT}" ]; then
        _log "sas bay for ${_F}: port ${_AT:-empty} -> ${_SB}"
        _AT="${_SB}"
      fi
      case "${_AT}" in
        '' | *[!0-9]*) _AT=0 ;;
      esac
      if [ "${BOOTDISK_PCIEPATH}" = "${_PC}" ] && [ -n "${BOOTDISK_ATAPORT}" ] && [ "${BOOTDISK_ATAPORT}" = "${_AT}" ]; then
        _log "bootloader (port ${_AT}): ${_F}"; continue
      fi
      _claim_slot_port "${_PC}" "${_AT}" || { _log "no slot for ${_F}"; continue; }
      _AT="${_SLOT_PORT}"
      _log "hba disk without sata alias: ${_F} -> ${_PC} port ${_AT} (${_DR})"
      _emit_sata_slot "${_PC}" "${_DR}" "${_AT}"
    done

    # NVMe. PAS7700 (epyc7003ntb) maps it as storage - an internal_slot@ with
    # an nvme { } child - so those continue the internal_slot@ numbering of the
    # passes above; restarting at 0 would emit duplicate node names in a mixed
    # SATA+NVMe tree. Everywhere else NVMe is cache: nvme_slot@ numbered from 1,
    # each with a power_limit entry.
    _NVME_STORAGE=false
    echo "${UNIQUE}" | grep -q 'epyc7003ntb' && _NVME_STORAGE=true
    [ "${_NVME_STORAGE}" = true ] || COUNT=0
    POWER_LIMIT=""
    for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
      [ ! -e "${F}" ] && continue
      N="$(basename "${F}")"
      [ -n "${BOOTDISK}" ] && [ "${N}" = "${BOOTDISK}" ] && { _log "bootloader: ${F}"; continue; }
      _disk_info "${F}"
      [ -n "${_PC}" ] || { _log "unknown: ${F}"; continue; }
      # BOOTDISK_PCIEPATH comes straight from syno_block_info and may still be
      # the short form, so normalize it before comparing - otherwise the
      # loader's own NVMe drive is not recognized and gets a data slot.
      _NVME_BOOTPC="$(_pc_norm "${BOOTDISK_PCIEPATH}")"
      if { [ -n "${_NVME_BOOTPC}" ] && [ "${_NVME_BOOTPC}" = "${_PC}" ]; } || { [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${_PP}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "${_PP}" ]; }; then
        _log "bootloader: ${F}"
        continue
      fi
      # One slot per controller: DSM maps a cache/storage device per NVMe
      # controller, so further namespaces on it share the slot. Log it - a
      # silent skip is indistinguishable from a disk that was never detected.
      if grep -qF "pcie_root = \"${_PC}\";" "${DEST}"; then
        _log "already slotted: ${F} [${_PC}], an nvme controller only recognizes one disk"
        continue
      fi
      if [ "${_NVME_STORAGE}" = true ]; then
        COUNT=$((COUNT + 1))
        {
          echo "    internal_slot@${COUNT} {"
          echo "        nvme {"
          echo "            pcie_root = \"${_PC}\";"
          echo "        };"
          echo "    };"
        } >>"${DEST}"
        continue
      fi
      # power_limit is a fixed-width DSM field (30 chars), one entry per
      # nvme_slot. Past that the remaining drives genuinely cannot get a slot,
      # so say which ones were dropped instead of breaking silently - "some
      # disks are missing" with nothing in the log is the worst failure mode.
      if [ $((${#POWER_LIMIT} + 2)) -gt 30 ]; then
        _log "power_limit full at ${COUNT} nvme slot(s), no slot for ${F} [${_PC}]"
        continue
      fi
      POWER_LIMIT="${POWER_LIMIT:+${POWER_LIMIT},}0"
      COUNT=$((COUNT + 1))
      {
        echo "    nvme_slot@${COUNT} {"
        echo "        reg = <${COUNT}>;"
        echo "        pcie_root = \"${_PC}\";"
        echo '        port_type = "ssdcache";'
        echo "    };"
      } >>"${DEST}"
    done
    if [ "${_NVME_STORAGE}" != true ]; then
      [ -n "${POWER_LIMIT}" ] && sed -i "s/power_limit = .*/power_limit = \"${POWER_LIMIT}\";/" "${DEST}" || sed -i '/power_limit/d' "${DEST}"
    fi

    COUNT=0
    for I in $(getUsbPorts); do
      COUNT=$((COUNT + 1))
      {
        echo "    usb_slot@${COUNT} {"
        echo "      reg = <${COUNT}>;"
        echo "      usb2 {"
        echo "        usb_port = \"${I}\";"
        echo "      };"
        echo "      usb3 {"
        echo "        usb_port = \"${I}\";"
        echo "      };"
        echo "    };"
      } >>"${DEST}"
    done
    echo "};" >>"${DEST}"
  fi

  _release=$(/bin/uname -r)
  if [ "$(/bin/echo "${_release%%[-+]*}" | /usr/bin/cut -d'.' -f1)" -lt 5 ]; then
    sed -i 's/"0000:\([0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]\.[0-7]\(,[0-9a-f][0-9a-f]\.[0-7]\)\{0,1\}\)"/"\1"/g' "${DEST}"
  else
    sed -i 's/"\([0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]\.[0-7]\(,[0-9a-f][0-9a-f]\.[0-7]\)\{0,1\}\)"/"0000:\1"/g' "${DEST}"
  fi

  sed -i "0,/version = .*;/s/model = \".*\";/model = \"${UNIQUE}\";/" "${DEST}"

  MAXDISKS=$(grep -c "internal_slot@" "${DEST}" 2>/dev/null)
  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    _log "get maxdisks=${MAXDISKS:-0}"
  else
    [ "${MAXDISKS:-0}" -lt 26 ] && MAXDISKS=26
  fi
  if ! _check_rootraidstatus && [ "${MAXDISKS:-0}" -gt 26 ]; then
    MAXDISKS=26
    _log "set maxdisks=26 [${MAXDISKS:-0}]"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS:-0}"
  _log "maxdisks=${MAXDISKS:-0}"

  if grep -q "nvme_slot@" "${DEST}" 2>/dev/null; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"
    #__set_conf_kv "support_write_cache" "yes"
  fi

  _DTB_TMP="/tmp/model.dtb.$$"
  dtc -I dts -O dtb "${DEST}" >"${_DTB_TMP}"
  if [ $? -eq 0 ] && [ -s "${_DTB_TMP}" ]; then
    cat "${_DTB_TMP}" >/etc/model.dtb
    rm -f "${_DTB_TMP}"
    _log "dtc success"
    # Persist a ramdisk-only upload: /addons is gone once DSM is up, and this
    # copy is what later regenerations read back. Copy the pristine source
    # rather than ${DEST}, which carries this run's domain normalization and
    # model= rewrite - storing those would bake one kernel's BDF spelling into
    # the user's own file. A dts already read from /etc/user_model.dts needs no
    # write-back.
    [ "${USER_DTS}" = "/addons/model.dts" ] && cp -vpf "${USER_DTS}" /etc/user_model.dts
    rm -vf "${DEST}"
    cp -vpf /etc/model.dtb /etc.defaults/model.dtb
    cp -vpf /etc/model.dtb /run/model.dtb
    /usr/syno/bin/syno_slot_mapping
    # --no-block: this also runs as a udev PROGRAM, and storagepanel.service is
    # ordered After=pkgctl-StorageManager. During boot that package has not
    # started yet, so a blocking restart parked the udev worker until it had -
    # while every other disk's event queued behind our lock, delaying pool and
    # volume assembly (Storage Manager errors, File Station missing until the
    # next boot). Queueing the job is all this needs.
    [ -f "/usr/lib/systemd/system/storagepanel.service" ] && systemctl --no-block restart storagepanel.service
    return 0
  else
    _log "dtc error"
    rm -f "${_DTB_TMP}"
    # A user dts that does not compile is set aside as user_model.dts.bad, not
    # deleted: it is the user's own file and the only record of what to fix.
    # It must not stay at user_model.dts, or every later run would retry the
    # same broken source and never fall back to a working auto-generated tree.
    if [ -n "${USER_DTS}" ]; then
      cp -vpf "${USER_DTS}" /etc/user_model.dts.bad
      rm -vf /etc/user_model.dts
      _log "user dts failed to compile, kept as /etc/user_model.dts.bad"
    fi
    rm -vf "${DEST}"
    cp -vpf /etc.defaults/model.dtb /etc/model.dtb
    return 1
  fi
}

dtUpdate() {
  _log dtUpdate "$*"

  F="$(basename "${1:-}" 2>/dev/null)"
  if [ -z "${F}" ]; then
    _log "No disk found"
    return 1
  fi

  _disk_info "/sys/block/${F}"
  ATAPORT="${_AT}"
  USBPORT="$(sed -n 's/^usb_path=//p' "/sys/block/${F}/device/syno_block_info" 2>/dev/null)"

  if [ -z "${_PC}" ] && [ -z "${USBPORT}" ]; then
    _log "unknown: ${F}, triggering full dtModel"
    dtModel
    return $?
  fi

  # Look up without the domain. The dtb carries whichever spelling the running
  # kernel wants - bare on 4.x, 0000: on 5.x, applied at the end of dtModel -
  # while _PC is always prefixed. Matching the prefixed form against a 4.x dtb
  # found nothing, so on DT 4.4 every disk that needed the synthesized-port check
  # below rebuilt the whole tree on each udev event.
  _KEY="${_PC#0000:}"
  TEMP_DTS="/tmp/model.dts"
  dtc -I dtb -O dts /etc/model.dtb 2>/dev/null | sed 's/pcie_root = "0000:/pcie_root = "/' >"${TEMP_DTS}"

  sata_slot_find=""
  nvme_slot_find=""
  usb_slot_find=""
  case "${F}" in
    nvme*)
      # pcie_root alone: on epyc7003ntb NVMe is an internal_slot@ with an
      # nvme { } child rather than an nvme_slot@, and dtModel already
      # guarantees one NVMe slot per controller, so its presence means this
      # disk has a bay.
      nvme_slot_find="$(grep -F "pcie_root = \"${_KEY}\";" "${TEMP_DTS}" 2>/dev/null | head -1)"
      ;;
    *)
      # A non-numeric ata_port_no would make printf below fail mid-expansion
      # and produce a broken sed script, so treat it the same as an absent one.
      case "${ATAPORT}" in *[!0-9]*) ATAPORT="" ;; esac
      if [ -z "${ATAPORT}" ]; then
        sata_slot_find="$(grep -F "pcie_root = \"${_KEY}\";" "${TEMP_DTS}" 2>/dev/null | head -1)"
      else
        # dtModel writes <0x0A>, but dtc decompiles cells in lowercase and,
        # depending on its version, with or without the zero padding - <0x0a>
        # or <0xa>. Matching the uppercase form missed every port from 10 up.
        sata_slot_find="$(sed -n "/pcie_root = \"${_KEY}\";/{N;/ata_port = <0x0*$(printf '%x' "${ATAPORT}")>;/p}" "${TEMP_DTS}" 2>/dev/null)"
      fi
      # dtModel may have had to synthesize a port for this disk (SAS HBAs share
      # one pciepath and the vendor populator can report port 0 for every disk),
      # so the exact pair need not be present even though the disk does have a
      # bay. Comparing slot count against disk count on that controller tells the
      # two cases apart: as many slots as disks means this one is already mapped
      # under a synthesized port, and rebuilding on every udev event would only
      # reshuffle bays. Fewer slots than disks means one really is missing.
      if [ -z "${sata_slot_find}" ] && [ -n "${ATAPORT}" ]; then
        _DU_SLOTS="$(grep -cF "pcie_root = \"${_KEY}\";" "${TEMP_DTS}" 2>/dev/null)"
        _DU_DISKS=0
        for _DU_D in /sys/block/sata* /sys/block/sd*; do
          [ -e "${_DU_D}" ] || continue
          [ -n "${BOOTDISK}" ] && [ "$(basename "${_DU_D}")" = "${BOOTDISK}" ] && continue
          _disk_info "${_DU_D}"
          # Same exclusions dtModel applies, so the two counts stay comparable.
          case "${_PP}" in *usb*) continue ;; esac
          [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${_PP}" ] && \
            [ "${_PP}" = "${BOOTDISK_PHYSDEVPATH}" ] && continue
          [ -n "${_PC}" ] && [ "${_PC#0000:}" = "${_KEY}" ] || continue
          # By the controller's own address - see _disk_info. Using the
          # pciepath here never counted a disk behind a bridge, which switched
          # this check off for every add-in HBA.
          case "$(cat "/sys/bus/pci/devices/${_BDF}/class" 2>/dev/null)" in 0x01*) : ;; *) continue ;; esac
          _DU_DISKS=$((_DU_DISKS + 1))
        done
        if [ "${_DU_SLOTS:-0}" -ge "${_DU_DISKS}" ] && [ "${_DU_DISKS}" -gt 0 ]; then
          sata_slot_find="synthesized"
          _log "${F}: ata_port ${ATAPORT} not in dts, but ${_KEY} has ${_DU_SLOTS} slot(s) for ${_DU_DISKS} disk(s)"
        fi
      fi
      ;;
  esac
  [ -n "${USBPORT}" ] && usb_slot_find="$(sed -n "/usb3 {/{N;/usb_port = \"${USBPORT}\";/p}" "${TEMP_DTS}" 2>/dev/null)"
  rm -f "${TEMP_DTS}"
  if [ -n "${sata_slot_find}" ] || [ -n "${nvme_slot_find}" ] || [ -n "${usb_slot_find}" ]; then
    _log "${F} is in the model.dts"
    return 0
  fi

  dtModel
}

nondtModel() {
  _log nondtModel

  _wait_disks_stable "/sys/block/sd* /sys/block/nvme*"

  MAXDISKS=0
  USBPORTCFG=0
  ESATAPORTCFG=0
  INTERNALPORTCFG=0

  hasUSB=false
  USBMINIDX=99
  USBMAXIDX=0
  MAXNONUSBIDX=-1
  NONUSBMASK=0
  for _ND_N in $(LC_ALL=C printf '%s\n' /sys/block/sd* | sort -V); do
    _ND_N="$(basename "${_ND_N}")"
    F="/sys/block/${_ND_N}"
    [ -e "${F}" ] || continue
    if [ -n "${BOOTDISK}" ] && [ "${_ND_N}" = "${BOOTDISK}" ]; then
      _log "bootloader: ${F}"; continue
    fi
    if [ -n "${BOOTDISK_PHYSDEVPATH}" ]; then
      _N_PP="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
      if [ -n "${_N_PP}" ] && [ "${_N_PP}" = "${BOOTDISK_PHYSDEVPATH}" ]; then
        _log "bootloader (alias): ${F}"; continue
      fi
    fi
    if [ -n "${BOOTDISK_PCIEPATH}" ] && [ -n "${BOOTDISK_ATAPORT}" ]; then
      _N_PCIE="$(grep 'pciepath' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      _N_ATAPORT="$(grep 'ata_port_no' "${F}/device/syno_block_info" 2>/dev/null | cut -d'=' -f2)"
      if [ -n "${_N_PCIE}" ] && [ -n "${_N_ATAPORT}" ] && \
         [ "${_N_PCIE}" = "${BOOTDISK_PCIEPATH}" ] && [ "${_N_ATAPORT}" = "${BOOTDISK_ATAPORT}" ]; then
        _log "bootloader (pciepath+ataport): ${F}"; continue
      fi
    fi
    IDX="$(_atoi "${_ND_N#sd}")"
    BIT=$((2 ** IDX))
    [ $((IDX + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((IDX + 1))
    if grep "PHYSDEVPATH" "${F}/uevent" 2>/dev/null | grep -q "usb"; then
      [ ${IDX} -lt ${USBMINIDX} ] && USBMINIDX=${IDX}
      [ ${IDX} -gt ${USBMAXIDX} ] && USBMAXIDX=${IDX}
      hasUSB=true
    else
      NONUSBMASK=$((NONUSBMASK | BIT))
      [ ${IDX} -gt ${MAXNONUSBIDX} ] && MAXNONUSBIDX=${IDX}
    fi
  done

  # Reserve at least 6 USB slots, even when no USB disk is attached at boot:
  # a disk plugged in later must land in a slot that already exists, otherwise
  # it falls outside both masks and DSM has no bay for it. With "usbinternal"
  # the reserved range stays in internalportcfg, which is what makes USB disks
  # usable as internal disks. Never reserve across indices held by non-USB
  # disks (AHCI/HBA) - that would mis-classify them as USB.
  if [ "${hasUSB}" = "false" ]; then
    USBMINIDX=$((MAXNONUSBIDX + 1))
    [ ${USBMINIDX} -lt ${MAXDISKS} ] && USBMINIDX=${MAXDISKS}
    USBMAXIDX=$((USBMINIDX + 6 - 1))
  elif [ ${MAXNONUSBIDX} -lt ${USBMINIDX} ]; then
    [ $((USBMAXIDX - USBMINIDX)) -lt $((6 - 1)) ] && USBMAXIDX=$((USBMINIDX + 6 - 1))
  fi
  [ $((USBMAXIDX + 1)) -gt ${MAXDISKS} ] && MAXDISKS=$((USBMAXIDX + 1))

  if _check_user_conf "maxdisks"; then
    MAXDISKS=$(($(__get_conf_kv maxdisks)))
    printf "get maxdisks=%d\n" "${MAXDISKS}"
  else
    printf "cal maxdisks=%d\n" "${MAXDISKS}"
  fi

  if grep -wq "usbinternal" /proc/cmdline 2>/dev/null; then
    USBPORTCFG=0
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  elif _check_user_conf "usbportcfg"; then
    USBPORTCFG=$(($(__get_conf_kv usbportcfg)))
    printf 'get usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  else
    # shellcheck disable=SC3019
    USBPORTCFG=$(($((2 ** $((USBMAXIDX + 1)) - 1)) ^ $((2 ** USBMINIDX - 1))))
    OVERLAPMASK=$((USBPORTCFG & NONUSBMASK))
    if [ ${OVERLAPMASK} -ne 0 ]; then
      USBPORTCFG=$((USBPORTCFG ^ OVERLAPMASK))
      _log "fix usbportcfg overlap: clear mask=0x$(printf '%x' ${OVERLAPMASK})"
    fi
    __set_conf_kv "usbportcfg" "$(printf '0x%.2x' ${USBPORTCFG})"
    printf 'set usbportcfg=0x%.2x\n' "${USBPORTCFG}"
  fi
  if _check_user_conf "esataportcfg"; then
    ESATAPORTCFG=$(($(__get_conf_kv esataportcfg)))
    printf 'get esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
  else
    __set_conf_kv "esataportcfg" "$(printf "0x%.2x" ${ESATAPORTCFG})"
    printf 'set esataportcfg=0x%.2x\n' "${ESATAPORTCFG}"
    __set_conf_kv "eunitseq" "$(IFS=, _itol ${ESATAPORTCFG})"
  fi
  if _check_user_conf "internalportcfg"; then
    INTERNALPORTCFG=$(($(__get_conf_kv internalportcfg)))
    printf 'get internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  else
    # shellcheck disable=SC3019
    INTERNALPORTCFG=$(($((2 ** MAXDISKS - 1)) ^ USBPORTCFG ^ ESATAPORTCFG))
    __set_conf_kv "internalportcfg" "$(printf "0x%.2x" ${INTERNALPORTCFG})"
    printf 'set internalportcfg=0x%.2x\n' "${INTERNALPORTCFG}"
  fi

  if ! _check_rootraidstatus && [ ${MAXDISKS} -gt 26 ]; then
    MAXDISKS=26
    printf "set maxdisks=26 [%d]\n" "${MAXDISKS}"
  fi
  __set_conf_kv "maxdisks" "${MAXDISKS}"
  printf "set maxdisks=%d\n" "${MAXDISKS}"

  COUNT=0
  echo "[pci]" >/etc/extensionPorts
  for F in $(LC_ALL=C printf '%s\n' /sys/block/nvme* | sort -V); do
    [ ! -e "${F}" ] && continue
    PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "${F}/uevent" 2>/dev/null)"
    # extensionPorts names the port an M.2 slot hangs off: the bridge directly
    # above the NVMe controller, as on real non-DT units (DS918+ lists
    # pci1="0000:00:13.1" for a drive at 0000:01:00.0). Only a controller that
    # sits on the root bus itself - the usual VM layout - is its own entry.
    # 05b67c8 switched this to the controller's own address, which agrees with
    # that only in the VM case; RR's original took the parent as well.
    PCIEPATH="$(_physdev_bdfs "${PHYSDEVPATH}" | tail -2 | head -1)"
    if [ -z "${PCIEPATH}" ]; then
      _log "unknown: ${F}"
      continue
    fi
    # Both sides must be non-empty before comparing. With no loader disk
    # resolved BOOTDISK_PHYSDEVPATH is empty, and a drive whose uevent cannot be
    # read yields an empty PHYSDEVPATH too - "" = "" then matched and the drive
    # was dropped as the bootloader, losing a real NVMe controller.
    #
    # PCIEPATH here is always domain-prefixed while BOOTDISK_PCIEPATH may still
    # be the short form from syno_block_info, so normalize it before comparing.
    _ND_BOOTPC="$(_pc_norm "${BOOTDISK_PCIEPATH}")"
    if { [ -n "${BOOTDISK_PHYSDEVPATH}" ] && [ -n "${PHYSDEVPATH}" ] && [ "${BOOTDISK_PHYSDEVPATH}" = "${PHYSDEVPATH}" ]; } || \
       { [ -n "${_ND_BOOTPC}" ] && [ "${_ND_BOOTPC}" = "${PCIEPATH}" ]; }; then
      _log "bootloader: ${F}"
      continue
    fi
    # Match the whole value, not a substring: the BDF's dots are regex
    # wildcards and the old unanchored grep also matched any longer path that
    # merely contained this one, silently dropping a real controller.
    if grep -qF "=\"${PCIEPATH}\"" /etc/extensionPorts; then
      _log "already: ${F} [${PCIEPATH}], an nvme controller only recognizes one disk"
      continue
    fi
    COUNT=$((COUNT + 1))
    echo "pci${COUNT}=\"${PCIEPATH}\"" >>/etc/extensionPorts
  done

  if [ "${COUNT}" -gt 0 ]; then
    __set_conf_kv "supportnvme" "yes"
    __set_conf_kv "support_m2_pool" "yes"
    #__set_conf_kv "support_ssd_cache" "yes"
    #__set_conf_kv "support_write_cache" "yes"
  fi
}

if type flock >/dev/null 2>&1 && type trap >/dev/null 2>&1; then
  LOCKFILE="/var/run/disks.lock"
  exec 3>"$LOCKFILE"
  # busybox flock has no -w/-u: it only understands "flock [-sxn] FD|file CMD".
  # Probing -w against our own fd would consume the lock, so probe the option on
  # a throwaway fd instead, then take the real lock with whichever form works.
  # Without this the junior ramdisk (busybox) fails every run with
  # "flock: invalid option -- 'w'" and disks.sh never generates model.dtb.
  _DISKS_FLOCK_UTIL=0
  if flock -w 0 9 9>/dev/null >/dev/null 2>&1; then
    _DISKS_FLOCK_UTIL=1
  fi
  if [ "${_DISKS_FLOCK_UTIL}" -eq 1 ]; then
    flock -w 60 3 || {
      _log "Failed to acquire lock after 60 seconds. Exiting."
      exit 1
    }
    trap 'flock -u 3; rm -f "$LOCKFILE"' EXIT INT TERM HUP
  else
    # busybox: -n is non-blocking; retry to approximate the 60s timeout above.
    _DISKS_LOCK_TRY=0
    while ! flock -n 3 2>/dev/null; do
      _DISKS_LOCK_TRY=$((_DISKS_LOCK_TRY + 1))
      if [ "${_DISKS_LOCK_TRY}" -ge 60 ]; then
        _log "Failed to acquire lock after 60 seconds. Exiting."
        exit 1
      fi
      sleep 1
    done
    # No -u: closing fd 3 releases the lock.
    trap 'exec 3>&-; rm -f "$LOCKFILE"' EXIT INT TERM HUP
  fi
fi

[ -z "$(/sbin/blkid -L ARC3 2>/dev/null)" ] && checkAlldisk

BOOTDISK_PART3_PATH="$(/sbin/blkid -L ARC3 2>/dev/null)"
if [ -n "${BOOTDISK_PART3_PATH}" ]; then
  BOOTDISK_PART3_MAJORMINOR="$(stat -c '%t:%T' "${BOOTDISK_PART3_PATH}" | awk -F: '{printf "%d:%d", strtonum("0x" $1), strtonum("0x" $2)}')"
  BOOTDISK_PART3="$(awk -F= '/DEVNAME/ {print $2}' "/sys/dev/block/${BOOTDISK_PART3_MAJORMINOR}/uevent" 2>/dev/null)"
fi

if [ -n "${BOOTDISK_PART3}" ]; then
  BOOTDISK="$(basename "$(dirname /sys/block/*/${BOOTDISK_PART3} 2>/dev/null)" 2>/dev/null)"
  BOOTDISK_PHYSDEVPATH="$(awk -F= '/PHYSDEVPATH/ {print $2}' "/sys/block/${BOOTDISK}/uevent" 2>/dev/null)"
fi

if [ -n "${BOOTDISK}" ]; then
  BOOTDISK_PCIEPATH="$(grep 'pciepath' /sys/block/${BOOTDISK}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
  BOOTDISK_ATAPORT="$(grep 'ata_port_no' /sys/block/${BOOTDISK}/device/syno_block_info 2>/dev/null | cut -d'=' -f2)"
  # Same derivation as the disks it is compared against (_disk_info).
  if [ -z "${BOOTDISK_PCIEPATH}" ] && [ -n "${BOOTDISK_PHYSDEVPATH}" ]; then
    BOOTDISK_PCIEPATH="$(_physdev_pciepath "${BOOTDISK_PHYSDEVPATH}")"
  fi
fi

echo "BOOTDISK=${BOOTDISK}"
echo "BOOTDISK_PHYSDEVPATH=${BOOTDISK_PHYSDEVPATH}"
echo "BOOTDISK_PCIEPATH=${BOOTDISK_PCIEPATH}"
echo "BOOTDISK_ATAPORT=${BOOTDISK_ATAPORT}"

checkSynoboot

case ${1} in
  "--create")
    if [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
      dtModel
    else
      nondtModel
    fi
    ;;
  "--update")
    if [ "$(__get_conf_kv supportportmappingv2)" = "yes" ]; then
      # No user_model.dts guard here. It used to skip the update entirely so a
      # udev event could not regenerate over an upload - but dtModel now reads
      # user_model.dts as its source, so a rebuild reproduces the user's tree
      # instead of replacing it. Keeping the guard only meant a disk plugged
      # into a slot the upload does not describe never got a bay at all.
      dtUpdate "${2:-}"
    else
      # Non-DT has no per-disk state to patch: the port masks are derived from
      # the whole disk set, so any change means recomputing them - unless the
      # user pinned all three, in which case there is nothing left to compute.
      if ! _check_user_conf "usbportcfg" || ! _check_user_conf "esataportcfg" || ! _check_user_conf "internalportcfg"; then
        _log "nondtUpdate ${2:-}"
        nondtModel
      fi
    fi
    ;;
  *)
    echo "Usage: $0 [--create|--update]"
    echo
    echo "       --create: create dts file and update synoinfo.conf"
    echo "       --update: update dts file and update synoinfo.conf"
    exit 1
    ;;
esac

exit 0
