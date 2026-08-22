import os
import tempfile
import unittest
from pathlib import Path

import alchemy_autobuild as a


class EnvironmentContractTests(unittest.TestCase):
    def test_package_and_test_environment_can_differ(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            pkg = d / "pkg"
            repo = d / "repo"
            for p in (pkg / "common", pkg / "gate", pkg / "communication", repo / "effect", repo / "feed"):
                p.mkdir(parents=True, exist_ok=True)
            c = {"root": d / "auto", "repo": repo}
            base = a.environment({
                "set": {"REPUTATION_EFFECT_ROOT": "${REPO_ROOT}/effect"},
                "rexx_path": {"mode": "replace", "entries": ["common"], "require_entries": True},
                "require_dirs": ["REPUTATION_EFFECT_ROOT"],
                "report": ["REPUTATION_EFFECT_ROOT"]
            }, pkg, c)
            gate = a._apply_environment(base, {
                "set": {"REPUTATION_FEED_ROOT": "${REPO_ROOT}/feed"},
                "rexx_path": {"mode": "replace", "entries": ["gate"]}
            }, pkg, c)
            comms = a._apply_environment(base, {
                "rexx_path": {"mode": "replace", "entries": ["communication"]}
            }, pkg, c)
            self.assertEqual(gate["REPUTATION_FEED_ROOT"], str(repo / "feed"))
            self.assertEqual(gate["REXX_PATH"], str(pkg / "gate"))
            self.assertEqual(comms["REXX_PATH"], str(pkg / "communication"))

    def test_two_scripts_receive_different_effective_environments(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            pkg = d / "pkg"
            repo = d / "repo"
            effect = repo / "effect"
            feed = repo / "feed"
            for p in (pkg / "gate", pkg / "communication", effect, feed):
                p.mkdir(parents=True, exist_ok=True)
            c = {"root": d / "auto", "repo": repo}
            env = a.environment({
                "set": {"REPUTATION_EFFECT_ROOT": "${REPO_ROOT}/effect"},
                "require_dirs": ["REPUTATION_EFFECT_ROOT"],
                "report": ["REPUTATION_EFFECT_ROOT"]
            }, pkg, c)
            old = a._CTX
            a._CTX = {
                "package": {"require_dirs": ["REPUTATION_EFFECT_ROOT"], "report": ["REPUTATION_EFFECT_ROOT"]},
                "tests": [
                    {
                        "set": {"PROBE_KIND": "gate"},
                        "rexx_path": {"mode": "replace", "entries": ["gate"], "require_entries": True},
                        "require": ["PROBE_KIND"],
                        "report": ["PROBE_KIND"]
                    },
                    {
                        "set": {"PROBE_KIND": "communication", "REPUTATION_FEED_ROOT": "${REPO_ROOT}/feed"},
                        "rexx_path": {"mode": "replace", "entries": ["communication"], "require_entries": True},
                        "require_dirs": ["REPUTATION_FEED_ROOT"],
                        "report": ["PROBE_KIND", "REPUTATION_FEED_ROOT"]
                    }
                ],
                "index": 0
            }
            try:
                code = "import os,sys; k=sys.argv[1]; assert os.environ['PROBE_KIND']==k; assert os.path.basename(os.environ['REXX_PATH'])==k"
                one = a._patched_run(["python3", "-c", code, "gate"], str(pkg), env, 5)
                two = a._patched_run(["python3", "-c", code, "communication"], str(pkg), env, 5)
            finally:
                a._CTX = old
            self.assertEqual(one["returncode"], 0)
            self.assertEqual(two["returncode"], 0)
            self.assertTrue(one["environment"]["REXX_PATH"].endswith("/gate"))
            self.assertTrue(two["environment"]["REXX_PATH"].endswith("/communication"))
            self.assertEqual(one["environment"]["PROBE_KIND"], "gate")
            self.assertEqual(two["environment"]["REPUTATION_FEED_ROOT"], str(feed))

    def test_missing_required_export_fails_before_script(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            pkg = d / "pkg"
            pkg.mkdir()
            c = {"root": d / "auto", "repo": d / "repo"}
            env = a.environment({}, pkg, c)
            old = a._CTX
            a._CTX = {"package": {}, "tests": [{"require": ["MISSING_ROOT"], "report": ["MISSING_ROOT"]}], "index": 0}
            try:
                r = a._patched_run(["sh", "-c", "exit 0"], str(pkg), env, 1)
            finally:
                a._CTX = old
            self.assertEqual(r["returncode"], 125)
            self.assertIn("MISSING_ROOT", r["stderr"])
            self.assertIsNone(r["environment"]["MISSING_ROOT"])

    def test_schema_03_accepts_test_environment_and_rejects_bad_mode(self):
        good = {
            "schema": a.SCHEMA,
            "package": {"name": "x", "version": "1"},
            "tests": [{"argv": ["true"], "environment": {"rexx_path": {"mode": "replace", "entries": ["."]}}}],
            "publish": {"artifact_only": True}
        }
        a.validate(good)
        bad = dict(good)
        bad["tests"] = [{"argv": ["true"], "environment": {"rexx_path": {"mode": "mystery", "entries": []}}}]
        with self.assertRaises(ValueError):
            a.validate(bad)


if __name__ == "__main__":
    unittest.main()
