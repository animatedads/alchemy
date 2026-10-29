import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
import zipfile

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import ComputerActions as actions


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.old_env = os.environ.copy()
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(self.old_env)))
        os.environ["XDG_CONFIG_HOME"] = str(self.root / "config")
        os.environ["HOME"] = str(self.root)
        self.downloads = self.root / "Downloads"
        self.current = self.downloads / "current"
        self.current.mkdir(parents=True)
        (self.current / "Crypto.cls").write_text("::class Crypto\n", encoding="utf-8")
        (self.current / "example.rex").write_text("needle special word\n", encoding="utf-8")
        with zipfile.ZipFile(self.downloads / "oorexx_crypto_v0.8.3.zip", "w") as z:
            z.writestr("src/Crypto.cls", "::class Crypto public\n")
        actions.add_root(f"add {self.downloads} to my find file locations", False)
        actions.add_root(f"add {self.current} to my find file locations", False)

    def capture(self, fn, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = fn(*args)
        return rc, out.getvalue()

    def test_state_persisted_no_duplicate_and_mode(self):
        rc, out = self.capture(actions.add_root, f"add {self.downloads} to my find file locations", False)
        self.assertEqual(rc, 0)
        self.assertIn("ALREADY_PRESENT", out)
        data = actions.load_state()
        self.assertEqual(len(data["search_roots"]), 2)
        self.assertEqual(os.stat(actions.config_path()).st_mode & 0o777, 0o600)

    def test_temp_root_and_audit(self):
        self.assertEqual(actions.add_root("add /tmp to my permitted temporary file directory", True), 0)
        self.assertIn("/tmp", actions.load_state()["temp_roots"])
        actions.audit("CONFIG_SHOW", "do not log this sensitive phrase", 0)
        body = (actions.config_dir() / "audit.jsonl").read_text()
        self.assertNotIn("do not log", body)
        self.assertIn('"exit_code": 0', body)
        self.assertEqual((actions.config_dir() / "audit.jsonl").stat().st_mode & 0o777, 0o600)

    def test_recent_and_dedup(self):
        rc, output = self.capture(actions.recent, "find files received in my find files location in the past 30 minutes")
        self.assertEqual(rc, 0)
        self.assertIn("receipt time is not verified", output)
        self.assertEqual(output.count("/Crypto.cls"), 1)

    def test_content_search_and_zip(self):
        self.assertIn("example.rex", self.capture(actions.contents, "which file has needle")[1])
        output = self.capture(actions.contents, "which file has ::class Crypto public")[1]
        self.assertIn(".zip!src/Crypto.cls", output)
        with self.assertRaises(actions.ComputerError):
            actions.contents("which file has")

    def test_latest_semver_class(self):
        rc, output = self.capture(actions.latest_class, "find the latest copy of Crypto rexx class")
        self.assertEqual(rc, 0)
        self.assertIn("oorexx_crypto_v0.8.3.zip!src/Crypto.cls", output)
        self.assertIn("candidate_not_verified_release", output)

    def test_rexxpath_does_not_modify_shell(self):
        previous = os.environ.get("REXX_PATH", "")
        rc, output = self.capture(actions.rexxpath, "set up the rexxpath", True)
        self.assertEqual(rc, 0)
        self.assertTrue((actions.config_dir() / "rexxpath.sh").exists())
        self.assertIn(str(self.current), (actions.config_dir() / "rexxpath.sh").read_text())
        self.assertEqual(previous, os.environ.get("REXX_PATH", ""))

    def test_ssh_is_dry_and_firewall_blocks(self):
        os.environ["COMPUTER_DRY_RUN"] = "1"
        self.assertIn("sshnode.sh ed209b", self.capture(actions.login, "log me into ED209B")[1])
        rc, output = self.capture(actions.firewall, "fix the firewall on ed209f")
        self.assertEqual(rc, 4)
        self.assertIn("node absent", output)

    def test_no_shell_injection_and_unknown_node(self):
        trigger = self.root / "PWNED"
        with self.assertRaises(actions.ComputerError):
            actions.login(f"log me into ed209b; touch {trigger}")
        self.assertFalse(trigger.exists())
        with self.assertRaises(actions.ComputerError):
            actions.login("log me into ed209f")

    def test_missing_root_is_not_silent(self):
        (self.current / "example.rex").unlink()
        (self.current / "Crypto.cls").unlink()
        self.assertNotIn("example.rex", self.capture(actions.contents, "which file has needle")[1])
        with self.assertRaises(actions.ComputerError):
            actions.add_root("add /no/such/directory to my find file locations", False)


if __name__ == "__main__":
    unittest.main()
