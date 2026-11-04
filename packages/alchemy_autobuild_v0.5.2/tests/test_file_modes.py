"""Alchemy Autobuild v0.5.2 acceptance: executable files stay executable.

Author: Claude (Opus 5.5), 2026-11-04. Architecture: Tom Dyer.

Each test drives the real runner against a real local Git remote. The test
package runs its script directly (argv ["./run_tests.sh"]), which is what
llm_gopher 0.22-dev1 (./gopher) and the SSC machine (tests/*.sh) do. Under
v0.5.1 these runs end FAIL with "Permission denied". Set
AUTOBUILD_UNDER_TEST to another entry point to show that.
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
import importlib.util

HERE = Path(__file__).resolve().parent
PKG = HERE.parent
SCRIPT = Path(os.environ.get("AUTOBUILD_UNDER_TEST") or (PKG / "alchemy_autobuild.py"))
REPO_ROOT = Path(os.environ.get("ALCHEMY_REPO_ROOT") or PKG.parents[1])
SUBMIT = REPO_ROOT / "tools" / "alchemy_submit.py"


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.strip()


def package_files(name, version):
    m = {
        "schema": "alchemy.autobuild.integration/0.3",
        "package": {"name": name, "version": version, "kind": "oorexx"},
        "working_directory": ".",
        "tests": [{"name": "direct-exec", "argv": ["./run_tests.sh"], "timeout_seconds": 30}],
        "publish": {"tree": {"source": ".", "path": f"packages/{name}_v{version}"}},
    }
    return {
        "integration.json": (json.dumps(m, indent=2), 0o644),
        "run_tests.sh": ("#!/bin/sh\nexec ./tests/inner.sh\n", 0o755),
        "tests/inner.sh": ("#!/bin/sh\necho inner-ran\n", 0o755),
        "src/Demo.cls": ("::class Demo public\n", 0o644),
    }


def load_module():
    name = "alchemy_autobuild_under_test_%d" % time.time_ns()
    spec = importlib.util.spec_from_file_location(name, SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FileModes(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ab052-"))
        self.remote = self.tmp / "remote.git"
        git("init", "--bare", "-b", "main", str(self.remote))
        seed = self.tmp / "seed"
        git("clone", "-q", str(self.remote), str(seed))
        git("config", "user.email", "seed@test", cwd=seed)
        git("config", "user.name", "seed", cwd=seed)
        (seed / "README.md").write_text("seed\n")
        git("add", "README.md", cwd=seed)
        git("commit", "-q", "-m", "seed", cwd=seed)
        git("push", "-q", "origin", "HEAD:main", cwd=seed)
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

    def remote_modes(self, prefix):
        out = git("ls-tree", "-r", "main", prefix, cwd=self.remote)
        return {line.split("\t")[1]: line.split()[0] for line in out.splitlines()}

    def result_for(self, run_id):
        check = self.tmp / "check"
        if check.exists():
            shutil.rmtree(check)
        git("clone", "-q", str(self.remote), str(check))
        return json.loads((check / "autobuild/results" / run_id / "result.json").read_text())

    def test_download_zip_keeps_execute_bits(self):
        mod = load_module()
        c = mod.load_config(str(self.cfg_path))
        runner = mod.Runner(c, start_ns=time.time_ns())
        tmpz = self.tmp / "modes.zip"
        with zipfile.ZipFile(tmpz, "w") as z:
            for name, (data, mode) in package_files("demo_modes_zip", "0.1").items():
                info = zipfile.ZipInfo("demo_modes_zip_v0.1/" + name)
                info.external_attr = mode << 16
                z.writestr(info, data)
        os.replace(tmpz, self.downloads / "modes.zip")
        self.assertEqual(runner.poll_downloads(), [])
        self.assertEqual(runner.poll_downloads(), [("modes.zip", "PASS")])
        modes = self.remote_modes("packages/demo_modes_zip_v0.1")
        self.assertEqual(modes["packages/demo_modes_zip_v0.1/run_tests.sh"], "100755")
        self.assertEqual(modes["packages/demo_modes_zip_v0.1/tests/inner.sh"], "100755")
        self.assertEqual(modes["packages/demo_modes_zip_v0.1/src/Demo.cls"], "100644")

    @unittest.skipUnless(SUBMIT.is_file(), "tools/alchemy_submit.py not present")
    def test_git_branch_submission_keeps_execute_bits(self):
        producer = self.tmp / "producer"
        git("clone", "-q", str(self.remote), str(producer))
        git("config", "user.email", "producer@test", cwd=producer)
        git("config", "user.name", "producer", cwd=producer)
        pkg = self.tmp / "branchpkg"
        for name, (data, mode) in package_files("demo_modes_git", "0.1").items():
            p = pkg / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)
            p.chmod(mode)
        sub = subprocess.run([sys.executable, str(SUBMIT), "--repo", str(producer), "--package", str(pkg),
                              "--submitted-by", "CLAUDE", "--json"],
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(sub.returncode, 0, sub.stderr[-2000:])
        sid = json.loads(sub.stdout)["submission_id"]
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.cfg_path)))
        out = runner.poll_git(force=True)
        self.assertIn((sid, "PASS"), out, out)
        modes = self.remote_modes("packages/demo_modes_git_v0.1")
        self.assertEqual(modes["packages/demo_modes_git_v0.1/run_tests.sh"], "100755")
        self.assertEqual(modes["packages/demo_modes_git_v0.1/tests/inner.sh"], "100755")

    def test_zip_mode_rules(self):
        mod = load_module()
        def info(mode):
            i = zipfile.ZipInfo("x")
            i.external_attr = mode << 16
            return i
        self.assertIsNone(mod.zip_mode(info(0)))               # no Unix attributes
        self.assertIsNone(mod.zip_mode(info(0o120777)))        # symlink entry
        self.assertEqual(mod.zip_mode(info(0o100755)), 0o755)
        self.assertEqual(mod.zip_mode(info(0o104755)), 0o755)  # setuid dropped
        self.assertEqual(mod.zip_mode(info(0o000444)), 0o644)  # owner rw kept

    def test_service_entry_point_names_version(self):
        p = subprocess.run([sys.executable, str(SCRIPT), "--config", str(self.cfg_path), "--once"],
                           cwd="/", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(p.returncode, 0, p.stderr[-2000:])
        state = json.loads((self.root / "runner-state.json").read_text())
        self.assertEqual(state["status"], "started")
        self.assertTrue(state["intake"].endswith("/0.5.2"), state)


if __name__ == "__main__":
    unittest.main()
