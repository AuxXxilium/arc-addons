#!/usr/bin/env sh
# SPDX-License-Identifier: GPL-3.0-only
# Restore disabled Intel USB routing on the tested Macmini7,1 configuration.

case "${1}" in modules|patches) ;; *) exit 0 ;; esac

# DSM spoofs the DMI product name. Limit this opt-in workaround to the tested
# CPU/controller combination instead of relying on that name.
grep -q 'i5-4278U' /proc/cpuinfo || exit 0
XHCI=/sys/bus/pci/devices/0000:00:14.0
[ "$(cat "${XHCI}/vendor" 2>/dev/null)" = "0x8086" ] || exit 0
[ "$(cat "${XHCI}/device" 2>/dev/null)" = "0x9c31" ] || exit 0
[ "$(cat "${XHCI}/subsystem_vendor" 2>/dev/null)" = "0x8086" ] || exit 0
[ "$(cat "${XHCI}/subsystem_device" 2>/dev/null)" = "0x7270" ] || exit 0
CFG="${XHCI}/config"

fail() {
  echo "macminixhci: ${1}" >&2
  exit 1
}

# xxd is available in the tested DSM installer; setpci is not.
USB3_MASK="$(xxd -p -s 220 -l 4 "${CFG}")" || fail "cannot read USB3PRM"
USB2_MASK="$(xxd -p -s 212 -l 4 "${CFG}")" || fail "cannot read USB2PRM"
[ "${USB3_MASK}" = "0f000000" ] && [ "${USB2_MASK}" = "ff010000" ] ||
  fail "unexpected USB routing masks; leaving controller unchanged"

USB3_CURRENT="$(xxd -p -s 216 -l 4 "${CFG}")" || fail "cannot read USB3_PSSEN"
USB2_CURRENT="$(xxd -p -s 208 -l 4 "${CFG}")" || fail "cannot read XUSB2PR"
# Refuse partial, unknown, or truncated values before writing either register.
case "${USB3_CURRENT}" in 00000000|"${USB3_MASK}") ;; *) fail "unexpected USB3 routing" ;; esac
case "${USB2_CURRENT}" in 00000000|"${USB2_MASK}") ;; *) fail "unexpected USB2 routing" ;; esac

CHANGED=false
# As in Linux usb_enable_intel_xhci_ports(), enable USB3 before routing USB2.
# These strings are raw little-endian bytes, not host-endian integers.
if [ "${USB3_CURRENT}" != "${USB3_MASK}" ]; then
  printf '000000d8: %s\n' "${USB3_MASK}" | xxd -r - "${CFG}" || fail "USB3 write failed"
  USB3_CURRENT="$(xxd -p -s 216 -l 4 "${CFG}")" || fail "USB3 readback failed"
  [ "${USB3_CURRENT}" = "${USB3_MASK}" ] || fail "USB3 readback mismatch"
  CHANGED=true
fi
if [ "${USB2_CURRENT}" != "${USB2_MASK}" ]; then
  printf '000000d0: %s\n' "${USB2_MASK}" | xxd -r - "${CFG}" || fail "USB2 write failed"
  USB2_CURRENT="$(xxd -p -s 208 -l 4 "${CFG}")" || fail "USB2 readback failed"
  [ "${USB2_CURRENT}" = "${USB2_MASK}" ] || fail "USB2 readback mismatch"
  CHANGED=true
fi
if [ "${CHANGED}" = "true" ]; then
  echo "macminixhci: restored Intel USB port routing"
  sleep 5 # Allow USB enumeration before the installer accesses synoboot.
fi
exit 0
