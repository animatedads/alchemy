"""Alchemy Autobuild v0.5.3 acceptance: the ooRexx Python gate runs first.

Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 2026-11-14.

Each test drives the real runner against a real local Git remote and the real
ooRexx gate from this repository. A machine without `rexx` FAILS these tests:
a gate that cannot run is NOT RUN, never PASS. Point AUTOBUILD_UNDER_TEST at
v0.5.2 to see the gate tests fail.
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
GATE = REPO_ROOT / "packages/oorexx_python_gate_v0.1/bin/python_gate.rex"
REXX = os.environ.get("REXX") or shutil.which("rexx")
GATE_NAME = "python-justification-gate"


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.strip()


def package_files(name, version, extra=None, test_env=None):
    test = {"name": "own-test", "argv": ["sh", "run_tests.sh"], "timeout_seconds": 30}
    if test_env:
        test["environment"] = test_env
    m = {
        "schema": "alchemy.autobuild.integration/0.3",
        "package": {"name": name, "version": version, "kind": "oorexx"},
        "working_directory": ".",
        "tests": [test],
        "publish": {"tree": {"source": ".", "path": f"packages/{name}_v{version}"}},
    }
    files = {
        "integration.json": json.dumps(m, indent=2),
        "run_tests.sh": "#!/bin/sh\necho own-test-ran \"${OWN_TEST_MARK:-unset}\"\n"
                        "[ -z \"${EXPECT_MARK:-}\" ] || [ \"${OWN_TEST_MARK:-}\" = \"$EXPECT_MARK\" ]\n",
        "src/Demo.cls": "::class Demo public\n",
    }
    files.update(extra or {})
    return files


def load_module():
    name = "alchemy_autobuild_under_test_%d" % time.time_ns()
    spec = importlib.util.spec_from_file_location(name, SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class PythonGate(unittest.TestCase):
    def setUp(self):
        self.assertTrue(REXX, "rexx not found: the gate cannot run, so this is a FAIL, not a skip")
        self.assertTrue(GATE.is_file(), "gate script missing: " + str(GATE))
        self.tmp = Path(tempfile.mkdtemp(prefix="ab053-"))
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

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def config(self, **gate):
        cfg = {
            "root": str(self.root), "downloads": str(self.downloads),
            "repo_dir": str(self.root / "repo"), "repo_url": str(self.remote),
            "branch": "main", "poll_seconds": 0.2, "git_poll_seconds": 0.2,
            "python_gate_script": str(GATE), "rexx": REXX,
        }
        cfg.update(gate)
        path = self.tmp / "config.json"
        path.write_text(json.dumps(cfg))
        return path

    def submit_zip(self, runner, name, files):
        tmpz = self.tmp / (name + ".tmp")
        with zipfile.ZipFile(tmpz, "w") as z:
            for rel, data in files.items():
                info = zipfile.ZipInfo(name + "_v0.1/" + rel)
                info.external_attr = 0o644 << 16
                z.writestr(info, data)
        os.replace(tmpz, self.downloads / (name + ".zip"))
        self.assertEqual(runner.poll_downloads(), [])          # first sighting: wait for stability
        return runner.poll_downloads()

    def remote_tree(self):
        out = git("ls-tree", "-r", "--name-only", "main", cwd=self.remote)
        return out.splitlines()

    def latest_result(self):
        check = self.tmp / "check"
        if check.exists():
            shutil.rmtree(check)
        git("clone", "-q", str(self.remote), str(check))
        results = sorted((check / "autobuild/results").glob("*/result.json"))
        self.assertTrue(results, "no result.json written")
        doc = json.loads(results[-1].read_text())
        logs = {}
        for t in doc["tests"]:
            logs[t["name"]] = (check / t["stdout_path"]).read_text() + (check / t["stderr_path"]).read_text()
        return doc, logs

    def test_clean_rexx_package_passes_with_gate_first(self):
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config())), start_ns=time.time_ns())
        self.assertEqual(self.submit_zip(runner, "demo_clean", package_files("demo_clean", "0.1")),
                         [("demo_clean.zip", "PASS")])
        doc, logs = self.latest_result()
        self.assertEqual([t["name"] for t in doc["tests"]], [GATE_NAME, "own-test"])
        self.assertEqual(doc["tests"][0]["status"], "PASS")
        self.assertIn('"status": "PASS"', logs[GATE_NAME])
        self.assertIn("packages/demo_clean_v0.1/src/Demo.cls", self.remote_tree())

    def test_unjustified_python_fails_and_is_not_published(self):
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config())), start_ns=time.time_ns())
        files = package_files("demo_py", "0.1", {
            "rexx.app.rex": '/* Complex rexx.app */\n"python3 codehehe.py"\nSay "I told you it was rexx"\n',
            "codehehe.py": "print('hehe')\n",
        })
        self.assertEqual(self.submit_zip(runner, "demo_py", files), [("demo_py.zip", "FAIL")])
        doc, logs = self.latest_result()
        self.assertEqual(doc["tests"][0]["name"], GATE_NAME)
        self.assertEqual(doc["tests"][0]["status"], "FAIL")
        self.assertIn("UNJUSTIFIED python-call rexx.app.rex", logs[GATE_NAME])
        self.assertIn("UNJUSTIFIED python-source codehehe.py", logs[GATE_NAME])
        self.assertFalse(any(p.startswith("packages/demo_py_v0.1/") for p in self.remote_tree()))

    def test_justified_python_passes(self):
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config())), start_ns=time.time_ns())
        files = package_files("demo_just", "0.1", {
            "tools/sdk.py": "import vendor_sdk\n",
            "PYTHON_JUSTIFICATION": "tools/sdk.py | the vendor ships only a Python SDK with no C API "
                                    "and no published wire protocol to implement in ooRexx\n",
        })
        self.assertEqual(self.submit_zip(runner, "demo_just", files), [("demo_just.zip", "PASS")])
        doc, logs = self.latest_result()
        self.assertIn("justified tools/sdk.py", logs[GATE_NAME])

    def test_advisory_mode_logs_but_does_not_fail(self):
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config(python_gate="advisory"))), start_ns=time.time_ns())
        files = package_files("demo_adv", "0.1", {"x.py": "print(1)\n"})
        self.assertEqual(self.submit_zip(runner, "demo_adv", files), [("demo_adv.zip", "PASS")])
        doc, logs = self.latest_result()
        self.assertIn('"status": "FAIL"', logs[GATE_NAME])
        self.assertIn("ADVISORY", logs[GATE_NAME])

    def test_missing_gate_script_fails_closed(self):
        mod = load_module()
        cfg = self.config(python_gate_script=str(self.tmp / "no_such_gate.rex"))
        runner = mod.Runner(mod.load_config(str(cfg)), start_ns=time.time_ns())
        self.assertEqual(self.submit_zip(runner, "demo_nogate", package_files("demo_nogate", "0.1")),
                         [("demo_nogate.zip", "FAIL")])

    def test_bad_mode_rejected_at_start(self):
        mod = load_module()
        with self.assertRaises(ValueError):
            mod.load_config(str(self.config(python_gate="off")))

    def test_per_test_environment_still_lines_up(self):
        """v0.4 matches environment specs by position; the gate must not shift them."""
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config())), start_ns=time.time_ns())
        files = package_files("demo_env", "0.1", test_env={"set": {"OWN_TEST_MARK": "mine", "EXPECT_MARK": "mine"}})
        self.assertEqual(self.submit_zip(runner, "demo_env", files), [("demo_env.zip", "PASS")])
        doc, logs = self.latest_result()
        self.assertIn("own-test-ran mine", logs["own-test"])

    @unittest.skipUnless(SUBMIT.is_file(), "tools/alchemy_submit.py not present")
    def test_git_branch_submission_is_gated(self):
        producer = self.tmp / "producer"
        git("clone", "-q", str(self.remote), str(producer))
        git("config", "user.email", "producer@test", cwd=producer)
        git("config", "user.name", "producer", cwd=producer)
        pkg = self.tmp / "branchpkg"
        for rel, data in package_files("demo_git_py", "0.1", {"helper.py": "print(1)\n"}).items():
            p = pkg / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)
        sub = subprocess.run([sys.executable, str(SUBMIT), "--repo", str(producer), "--package", str(pkg),
                              "--submitted-by", "CLAUDE", "--json"],
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(sub.returncode, 0, sub.stderr[-2000:])
        sid = json.loads(sub.stdout)["submission_id"]
        mod = load_module()
        runner = mod.Runner(mod.load_config(str(self.config())))
        out = runner.poll_git(force=True)
        self.assertIn((sid, "FAIL"), out, out)
        self.assertFalse(any(p.startswith("packages/demo_git_py_v0.1/") for p in self.remote_tree()))

    def test_service_entry_point_names_version_and_mode(self):
        p = subprocess.run([sys.executable, str(SCRIPT), "--config", str(self.config()), "--once"],
                           cwd="/", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        self.assertEqual(p.returncode, 0, p.stderr[-2000:])
        state = json.loads((self.root / "runner-state.json").read_text())
        self.assertTrue(state["intake"].endswith("/0.5.3"), state)
        self.assertEqual(state["python_gate"], "enforce")


if __name__ == "__main__":
    unittest.main()
