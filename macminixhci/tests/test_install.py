"""Exercise the real shell script without accessing hardware (Python 3 + xxd)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "install.sh"
XXD = shutil.which("xxd")
GREP = shutil.which("grep")
WRAPPER = r'''
import os
from pathlib import Path
import subprocess
import sys

root = Path(os.environ["FIXTURE"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "cat":
    path = root / Path(args[0]).name
    sys.stdout.write(path.read_text())
elif name == "grep":
    assert args[-1] == "/proc/cpuinfo"
    args[-1] = str(root / "cpuinfo")
    sys.exit(subprocess.call([os.environ["REAL_GREP"], *args]))
elif name == "xxd":
    assert args[-1] == "/sys/bus/pci/devices/0000:00:14.0/config"
    args[-1] = str(root / "config")
    if args[0] == "-r":
        data = sys.stdin.read()
        with (root / "writes").open("a") as log:
            log.write(data)
        offset = data.split(":")[0]
        if offset == os.environ.get("FAIL_WRITE"):
            sys.exit(1)
        if offset == os.environ.get("IGNORE_WRITE"):
            sys.exit(0)
        sys.exit(subprocess.run([os.environ["REAL_XXD"], *args],
                                input=data, text=True).returncode)
    offset = args[args.index("-s") + 1]
    if offset == os.environ.get("FAIL_READBACK") and (root / "writes").exists():
        sys.exit(1)
    if offset == os.environ.get("FAIL_READ"):
        sys.exit(1)
    if offset == os.environ.get("SHORT_READ"):
        print("00")
        sys.exit(0)
    sys.exit(subprocess.call([os.environ["REAL_XXD"], *args]))
elif name == "sleep":
    (root / "slept").write_text(" ".join(args))
else:
    raise AssertionError(name)
'''


@unittest.skipUnless(XXD and GREP, "xxd and grep are required")
class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for command in ("cat", "grep", "xxd", "sleep"):
            wrapper = self.bin / command
            wrapper.write_text("#!" + sys.executable + "\n" + WRAPPER)
            wrapper.chmod(0o755)
        for name, value in {"cpuinfo": "model name : Intel Core i5-4278U CPU",
                            "vendor": "0x8086", "device": "0x9c31",
                            "subsystem_vendor": "0x8086",
                            "subsystem_device": "0x7270"}.items():
            (self.root / name).write_text(value + "\n")
        self.initial = bytearray(256)
        self.initial[0xD4:0xD8] = bytes.fromhex("ff010000")
        self.initial[0xDC:0xE0] = bytes.fromhex("0f000000")
        (self.root / "config").write_bytes(self.initial)
        self.env = dict(os.environ, PATH=str(self.bin), FIXTURE=str(self.root),
                        REAL_XXD=XXD, REAL_GREP=GREP)

    def run_script(self, hook="modules", **env):
        return subprocess.run(["/bin/sh", str(SCRIPT), hook],
                              env=dict(self.env, **env), capture_output=True,
                              text=True, timeout=15)

    def writes(self):
        log = self.root / "writes"
        return log.read_text().splitlines() if log.exists() else []

    def set_register(self, offset, value):
        config = bytearray((self.root / "config").read_bytes())
        config[offset:offset + 4] = bytes.fromhex(value)
        (self.root / "config").write_bytes(config)

    def assert_untouched(self):
        self.assertEqual(self.writes(), [])
        self.assertFalse((self.root / "slept").exists())

    def test_restore_order_exact_bytes_and_idempotence(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.writes(), ["000000d8: 0f000000", "000000d0: ff010000"])
        expected = self.initial[:]
        expected[0xD8:0xDC] = bytes.fromhex("0f000000")
        expected[0xD0:0xD4] = bytes.fromhex("ff010000")
        self.assertEqual((self.root / "config").read_bytes(), expected)
        self.assertEqual((self.root / "slept").read_text(), "5")
        (self.root / "writes").unlink()
        (self.root / "slept").unlink()
        self.assertEqual(self.run_script("patches").returncode, 0)
        self.assert_untouched()

    def test_patches_can_restore_independently(self):
        self.assertEqual(self.run_script("patches").returncode, 0)
        self.assertEqual(len(self.writes()), 2)

    def test_other_hooks_do_nothing(self):
        for hook in ("early", "late", "rcExit", ""):
            self.assertEqual(self.run_script(hook).returncode, 0)
        self.assert_untouched()

    def test_hardware_guards(self):
        for name in ("cpuinfo", "vendor", "device", "subsystem_vendor", "subsystem_device"):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_text()
                path.write_text("unsupported\n")
                self.assertEqual(self.run_script().returncode, 0)
                self.assert_untouched()
                path.write_text(original)

    def test_missing_xxd(self):
        (self.bin / "xxd").unlink()
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assert_untouched()

    def test_unknown_masks_or_routing_fail_before_writes(self):
        for offset in (0xD0, 0xD4, 0xD8, 0xDC):
            with self.subTest(offset=offset):
                (self.root / "config").write_bytes(self.initial)
                self.set_register(offset, "01000000")
                self.assertNotEqual(self.run_script().returncode, 0)
                self.assert_untouched()

    def test_failed_or_truncated_reads_fail_before_writes(self):
        for offset in (208, 212, 216, 220):
            for failure in ("FAIL_READ", "SHORT_READ"):
                with self.subTest(offset=offset, failure=failure):
                    self.assertNotEqual(self.run_script(**{failure: str(offset)}).returncode, 0)
                    self.assert_untouched()

    def test_usb3_failure_prevents_usb2_write(self):
        for failure in ("FAIL_WRITE", "IGNORE_WRITE"):
            with self.subTest(failure=failure):
                (self.root / "writes").write_text("")
                self.assertNotEqual(self.run_script(**{failure: "000000d8"}).returncode, 0)
                self.assertEqual(self.writes(), ["000000d8: 0f000000"])
                self.assertEqual((self.root / "config").read_bytes(), self.initial)
                self.assertFalse((self.root / "slept").exists())

    def test_usb2_failure_is_reported(self):
        for failure in ("FAIL_WRITE", "IGNORE_WRITE"):
            with self.subTest(failure=failure):
                (self.root / "config").write_bytes(self.initial)
                (self.root / "writes").write_text("")
                self.assertNotEqual(self.run_script(**{failure: "000000d0"}).returncode, 0)
                self.assertEqual(len(self.writes()), 2)
                self.assertFalse((self.root / "slept").exists())

    def test_readback_io_failure_stops_processing(self):
        for offset, writes in ((216, 1), (208, 2)):
            with self.subTest(offset=offset):
                (self.root / "config").write_bytes(self.initial)
                if (self.root / "writes").exists():
                    (self.root / "writes").unlink()
                result = self.run_script(FAIL_READBACK=str(offset))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("readback failed", result.stderr)
                self.assertEqual(len(self.writes()), writes)
                self.assertFalse((self.root / "slept").exists())

    def test_only_disabled_register_is_written(self):
        for enabled, mask, write in ((0xD8, "0f000000", "000000d0: ff010000"),
                                     (0xD0, "ff010000", "000000d8: 0f000000")):
            with self.subTest(enabled=enabled):
                (self.root / "config").write_bytes(self.initial)
                (self.root / "writes").write_text("")
                self.set_register(enabled, mask)
                self.assertEqual(self.run_script().returncode, 0)
                self.assertEqual(self.writes(), [write])


if __name__ == "__main__":
    unittest.main()
