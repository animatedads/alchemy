"""Alchemy Autobuild v0.5.1 acceptance: the real program, a real (local) Git remote.

Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.

These tests exist because v0.5 was accepted by a suite that never started the
service. Every test here drives the actual v0.5.1 code path that systemd runs.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PKG = HERE.parent
SCRIPT = PKG / "alchemy_autobuild.py"
REPO_ROOT = Path(os.environ.get("ALCHEMY_REPO_ROOT") or PKG.parents[1])
SUBMIT = REPO_ROOT / "tools" / "alchemy_submit.py"


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.strip()


def make_zip(path, files, wrapper=None):
    with zipfile.ZipFile(path, "w") as z:
        for name, data in files.items():
            arc = (wrapper + "/" + name) if wrapper else name
            info = zipfile.ZipInfo(arc)
            info.external_attr = (0o755 if name.endswith(".sh") else 0o644) << 16
            z.writestr(info, data)


def manifest(name, version, test_exit=0, publish_tree=True):
    m = {
        "schema": "alchemy.autobuild.integration/0.3",
        "package": {"name": name, "version": version, "kind": "oorexx"},
        "working_directory": ".",
        "tests": [{"name": "acceptance", "argv": ["sh", "run_tests.sh"], "timeout_seconds": 30}],
        "publish": ({"tree": {"source": ".", "path": f"packages/{name}_v{version}"}}
                    if publish_tree else {"artifact_only": True}),
    }
    return {"integration.json": json.dumps(m, indent=2),
            "run_tests.sh": f"#!/bin/sh\necho test-ran\nexit {test_exit}\n",
            "src/Demo.cls": "::class Demo public\n"}


class AutobuildEndToEnd(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ab051-"))
        self.remote = self.tmp / "remote.git"
        git("init", "--bare", "-b", "main", str(self.remote))
        seed = self.tmp / "seed"
        git("clone", str(self.remote), str(seed))
        git("config", "user.email", "seed@test", cwd=seed)
        git("config", "user.name", "seed", cwd=seed)
        (seed / "README.md").write_text("seed\n")
        git("add", "README.md", cwd=seed)
        git("commit", "-m", "seed", cwd=seed)
        git("push", "origin", "HEAD:main", cwd=seed)
        self.root = self.tmp / "root"
        self.downloads = self.tmp / "Downloads"
        self.downloads.mkdir()
        self.cfg_path = self.tmp / "config.json"
        self.cfg_path.write_text(json.dumps({
            "root": str(self.root), "downloads": str(self.downloads),
            "repo_dir": str(self.root / "repo"), "repo_url": str(self.remote),
            "branch": "main", "poll_seconds": 0.2, "git_poll_seconds": 0.2,
        }))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def remote_files(self):
        check = self.tmp / "check"
        if check.exists():
            shutil.rmtree(check)
        git("clone", "-q", str(self.remote), str(check))
        return check

    def load(self):
        sys.path.insert(0, str(PKG))
        import importlib
        if "alchemy_autobuild" in sys.modules:
            del sys.modules["alchemy_autobuild"]
        mod = importlib.import_module("alchemy_autobuild")
        return mod, mod.load_config(str(self.cfg_path))

    def test_service_entry_point_starts(self):
        """The exact systemd ExecStart form must start, run one cycle and exit 0."""
        p = subprocess.run([sys.executable, str(SCRIPT), "--config", str(self.cfg_path), "--once"],
                           cwd="/", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(p.returncode, 0, p.stderr[-2000:])
        state = json.loads((self.root / "runner-state.json").read_text())
        self.assertNotIn("error", state["status"])
        s = subprocess.run([sys.executable, str(SCRIPT), "--config", str(self.cfg_path), "--status"],
                           cwd="/", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        self.assertEqual(s.returncode, 0, s.stderr)
        self.assertIn("runner-state", s.stdout)

    def test_download_batch_all_processed_oldest_first(self):
        mod, c = self.load()
        start = time.time_ns()
        runner = mod.Runner(c, start_ns=start)
        order = [
            ("a_wrapped_pass.zip", manifest("demo_wrapped", "0.1"), "demo_wrapped_v0.1"),
            ("b_root_pass.zip", manifest("demo_root", "0.1"), None),
            ("c_no_manifest.zip", {"readme.txt": "not a package"}, "something"),
            ("d_wrapped_fail.zip", manifest("demo_fail", "0.1", test_exit=1), "demo_fail_v0.1"),
            ("e_artifact_only.zip", manifest("demo_art", "0.1", publish_tree=False), "demo_art_v0.1"),
        ]
        for fname, files, wrapper in order:
            tmpz = self.tmp / fname
            make_zip(tmpz, files, wrapper)
            os.replace(tmpz, self.downloads / fname)
            time.sleep(0.02)
        self.assertEqual(runner.poll_downloads(), [])       # first sight: observed only
        decisions = runner.poll_downloads()                 # stable: processed
        self.assertEqual([d[0] for d in decisions], [o[0] for o in order])
        self.assertEqual(dict(decisions), {
            "a_wrapped_pass.zip": "PASS", "b_root_pass.zip": "PASS",
            "c_no_manifest.zip": "ignored-no-manifest", "d_wrapped_fail.zip": "FAIL",
            "e_artifact_only.zip": "PASS"})
        self.assertEqual(runner.poll_downloads(), [])       # each exactly once

        log = [json.loads(x) for x in (self.root / "intake.log").read_text().splitlines()]
        self.assertEqual([x["filename"] for x in log], [o[0] for o in order])
        self.assertEqual(log[0]["layout"], "wrapped")
        self.assertEqual(log[1]["layout"], "root")

        check = self.remote_files()
        self.assertTrue((check / "packages/demo_wrapped_v0.1/integration.json").is_file())
        self.assertTrue((check / "packages/demo_wrapped_v0.1/src/Demo.cls").is_file())
        self.assertTrue((check / "packages/demo_root_v0.1/run_tests.sh").is_file())
        self.assertFalse((check / "packages/demo_fail_v0.1").exists())
        self.assertFalse((check / "packages/demo_art_v0.1").exists())
        results = [json.loads(p.read_text()) for p in (check / "autobuild/results").glob("*/result.json")]
        self.assertEqual(sorted(r["status"] for r in results), ["FAIL", "PASS", "PASS", "PASS"])
        wrapped = [r for r in results if r["source"].get("kind") == "zip-wrapped"
                   and r["package"]["name"] == "demo_wrapped"]
        self.assertEqual(len(wrapped), 1)
        self.assertEqual(wrapped[0]["source"]["filename"], "a_wrapped_pass.zip")
        self.assertEqual(wrapped[0]["source"]["wrapper_dir"], "demo_wrapped_v0.1")
        self.assertRegex(wrapped[0]["source"]["original_sha256"], r"^[0-9a-f]{64}$")

    def test_preexisting_zip_is_outside_the_run(self):
        mod, c = self.load()
        make_zip(self.downloads / "old.zip", manifest("demo_old", "0.1"), "demo_old_v0.1")
        time.sleep(0.02)
        runner = mod.Runner(c)
        runner.poll_downloads()
        self.assertEqual(runner.poll_downloads(), [])

    @unittest.skipUnless(SUBMIT.is_file(), "tools/alchemy_submit.py not present")
    def test_git_branch_submission_is_received(self):
        producer = self.tmp / "producer"
        git("clone", "-q", str(self.remote), str(producer))
        git("config", "user.email", "producer@test", cwd=producer)
        git("config", "user.name", "producer", cwd=producer)
        pkg = self.tmp / "branchpkg"
        pkg.mkdir()
        for name, data in manifest("demo_branch", "0.1").items():
            p = pkg / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)
        (pkg / "run_tests.sh").chmod(0o755)
        sub = subprocess.run([sys.executable, str(SUBMIT), "--repo", str(producer), "--package", str(pkg),
                              "--submitted-by", "CLAUDE", "--json"],
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(sub.returncode, 0, sub.stderr[-2000:])
        sid = json.loads(sub.stdout)["submission_id"]

        mod, c = self.load()
        runner = mod.Runner(c)
        out = runner.poll_git(force=True)
        self.assertIn((sid, "PASS"), out, out)
        check = self.remote_files()
        receipt = json.loads((check / "autobuild/receipts" / (sid + ".json")).read_text())
        self.assertEqual(receipt["status"], "PASS")
        self.assertTrue((check / "packages/demo_branch_v0.1/integration.json").is_file())
        self.assertEqual(runner.poll_git(force=True), [])   # receipt makes it idempotent

    @unittest.skipUnless(SUBMIT.is_file(), "tools/alchemy_submit.py not present")
    def test_git_intake_switch_and_list_pending(self):
        producer = self.tmp / "producer"
        git("clone", "-q", str(self.remote), str(producer))
        git("config", "user.email", "producer@test", cwd=producer)
        git("config", "user.name", "producer", cwd=producer)
        pkg = self.tmp / "gated"
        pkg.mkdir()
        for name, data in manifest("demo_gated", "0.1").items():
            p = pkg / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)
        sub = subprocess.run([sys.executable, str(SUBMIT), "--repo", str(producer), "--package", str(pkg),
                              "--submitted-by", "CLAUDE", "--json"],
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(sub.returncode, 0, sub.stderr[-2000:])
        sid = json.loads(sub.stdout)["submission_id"]
        cfg = json.loads(self.cfg_path.read_text())
        cfg["git_intake"] = False
        self.cfg_path.write_text(json.dumps(cfg))
        lp = subprocess.run([sys.executable, str(SCRIPT), "--config", str(self.cfg_path), "--list-pending"],
                            cwd="/", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(lp.returncode, 0, lp.stderr[-2000:])
        self.assertIn(sid, lp.stdout.split())
        mod, c = self.load()
        self.assertFalse(c["git_intake"])
        self.assertEqual(mod.Runner(c).poll_git(force=True), [])
        check = self.remote_files()
        self.assertFalse((check / "autobuild/receipts" / (sid + ".json")).exists())


if __name__ == "__main__":
    unittest.main()
