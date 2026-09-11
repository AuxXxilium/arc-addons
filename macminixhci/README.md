# macminixhci

Opt-in, beta workaround for missing USB devices on the tested Apple Macmini7,1
(Intel Core i5-4278U, Intel `8086:9c31` xHCI at `0000:00:14.0`, subsystem
`8086:7270`). Enable the addon and rebuild the loader before booting DSM.
Initially offered only for apollolake; other CPUs and DSM platforms are untested.
The CPU/PCI checks constrain applicability but are not a unique Apple identity.

## Observed failure and recovery

On Arc 4.0.0 (build 260907), DS918+ / DSM 7.4.1-90080 (kernel 4.4.302),
a fresh installation repeatedly stopped at 55%. PAT checksum verification passed,
but the updater could not mount `/dev/synoboot2` and ended with error 21.
DSM enumerated only USB root hubs; the boot USB and `/dev/synoboot*` were missing.

PCI configuration showed disabled routing despite nonzero supported-port masks:

| Register | Offset | Observed value |
| --- | --- | --- |
| XUSB2PR | 0xD0 | 0x00000000 |
| USB2PRM | 0xD4 | 0x000001FF |
| USB3_PSSEN | 0xD8 | 0x00000000 |
| USB3PRM | 0xDC | 0x0000000F |

Writing USB3PRM to USB3_PSSEN, then USB2PRM to XUSB2PR, immediately restored USB
enumeration and the boot partitions. Installation then completed successfully
and DSM reached its welcome screen after reboot. The component that disabled
routing has not been identified; this does not establish an Arc regression.

## Behavior and scope

The addon runs at `modules` and `patches`, using `xxd` available in the tested DSM
installer. It follows the register sequence in Linux
[`usb_enable_intel_xhci_ports()`](https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable/+/v4.4/drivers/usb/host/pci-quirks.c).
It accepts only the measured masks and routing values that are either zero or
already equal to those masks. It verifies each write, leaves already enabled
registers alone, and waits five seconds only after a change. An unexpected value
or I/O error stops processing. A later failure can leave an earlier successful
write in place; the addon reports the failure and does not attempt a rollback.

DMI product names are spoofed in the tested DSM environment, so the guard uses
the tested CPU and PCI identifiers. No driver replacement, MSI setting, disk
partition, or persistent PCI firmware setting is involved. Disabling the addon
and rebuilding removes the workaround from subsequent DSM boots.

The original routing workaround was exercised on one physical machine. The
additional fail-closed checks and readback verification in this submission have
local fixture coverage, but this exact revised script has not been boot-tested
on that machine. Wider hardware and cold-boot testing are still needed.

## Local checks

Run `sh -n macminixhci/install.sh` and
`python3 -m unittest discover -s macminixhci/tests -v` from the repository root.
The tests substitute command wrappers and a temporary PCI configuration file;
they never access real PCI devices. Build with
`./compile-addons.sh macminixhci` in the repository's build environment.
