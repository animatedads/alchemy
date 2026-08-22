import json
import os
import subprocess
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

import alchemy_autobuild as a


def man(argv=None, schema=None, publish=None):
    m = {
        "schema": schema or a.SCHEMA,
        "package": {"name": "demo", "version": "0.1"},
        "environment": {"set": {}, "prepend_path": []},
        "tests": [
            {
                "name": "acceptance",
                "argv": argv or ["sh", "run_tests.sh"],
                "timeout_seconds": 10,
            }
        ],
    }
    m["publish"] = publish if publish is not None else {
        "tree": {"source": ".", "path": "packages/demo_v0.1"}
    }
    return m


def zmake(p, m=None, nested=False, extra=None):
    with zipfile.ZipFile(p, "w") as z:
        if m is not None:
            z.writestr("nested/integration.json" if nested else "integration.json", json.dumps(m))
        for k, v in (extra or {}).items():
            z.writestr(k, v)


def seed_remote(d):
    remote = d / "r.git"
    seed = d / "seed"
    subprocess.run(["git", "init", "--bare", str(remote)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(
        ["git", "clone", str(remote), str(seed)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(["git", "-C", str(seed), "config", "user.name", "seed"], check=True)
    subprocess.run(["git", "-C", str(seed), "config", "user.email", "seed@x"], check=True)
    (seed / "README").write_text("x")
    subprocess.run(["git", "-C", str(seed), "add", "README"], check=True)
    subprocess.run(["git", "-C", str(seed), "commit", "-m", "seed"], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["git", "-C", str(seed), "branch", "-M", "main"], check=True)
    subprocess.run(
        ["git", "-C", str(seed), "push", "-u", "origin", "main"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(["git", "--git-dir", str(remote), "symbolic-ref", "HEAD", "refs/heads/main"], check=True)
    return remote


class T(unittest.TestCase):
    def test_defaults(self):
        self.assertEqual(a.defaults()["repo_url"], "git@github-alchemy:animatedads/alchemy.git")

    def test_start_watermark_latest_shallow(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            dl = d / "Downloads"
            dl.mkdir()
            zmake(dl / "old.zip", man())
            (dl / "sub").mkdir()
            zmake(dl / "sub" / "nested.zip", man())
            time.sleep(0.003)
            start = time.time_ns()
            zmake(dl / "a.zip", man())
            time.sleep(0.003)
            zmake(dl / "b.zip", man())
            self.assertEqual(a.candidate(dl, start)[0].name, "b.zip")

    def test_root_manifest_only(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "x.zip"
            zmake(p, man(), True)
            self.assertIsNone(a.manifest(p))

    def test_argv_only(self):
        m = man()
        m["tests"][0]["command"] = "echo no"
        with self.assertRaises(ValueError):
            a.validate(m)

    def test_v2_requires_explicit_source_publication_or_artifact_only(self):
        m = man(publish={})
        with self.assertRaises(ValueError):
            a.validate(m)
        a.validate(man(publish={"artifact_only": True}))

    def test_v1_remains_compatible(self):
        m = man(schema=a.SCHEMA_V1, publish={})
        a.validate(m)

    def test_safe_extract(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            p = d / "x.zip"
            with zipfile.ZipFile(p, "w") as z:
                z.writestr("../x", "x")
            with self.assertRaises(ValueError):
                a.extract(p, d / "out")

    def test_env(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "bin").mkdir()
            c = a.defaults()
            c["root"] = d / "auto"
            c["repo"] = d / "repo"
            e = a.environment(
                {"set": {"X": "${PACKAGE_ROOT}/x"}, "prepend_path": ["bin"]},
                d,
                c,
            )
            self.assertEqual(e["X"], str(d / "x"))
            self.assertEqual(e["PATH"].split(os.pathsep)[0], str(d / "bin"))

    def test_publish_tree_collision_protection(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            pkg = d / "pkg"
            repo = d / "repo"
            pkg.mkdir()
            repo.mkdir()
            (pkg / "x.txt").write_text("one")
            c = a.defaults()
            c["repo"] = repo
            m = man()
            self.assertEqual(a.publish_tree(m, pkg, c), "packages/demo_v0.1")
            self.assertEqual((repo / "packages/demo_v0.1/x.txt").read_text(), "one")
            # Re-publishing byte-identical content is a harmless no-op.
            self.assertEqual(a.publish_tree(m, pkg, c), "packages/demo_v0.1")
            (pkg / "x.txt").write_text("two")
            with self.assertRaises(ValueError):
                a.publish_tree(m, pkg, c)

    def test_failed_tests_do_not_promote_source_tree(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = seed_remote(d)
            dl = d / "Downloads"
            dl.mkdir()
            start = time.time_ns()
            p = dl / "bad.zip"
            m = man(argv=["sh", "-c", "exit 7"])
            zmake(p, m, extra={"source.cls": "bad"})
            c = a.defaults()
            c.update(root=d / "auto", repo=d / "auto" / "repo", downloads=dl, repo_url=str(remote))
            r = a.integrate(p, p.stat(), a.manifest(p), c, start)
            self.assertEqual(r["status"], "FAIL")
            self.assertFalse((c["repo"] / "packages/demo_v0.1").exists())
            self.assertTrue((c["repo"] / r["artifact_path"]).exists())

    def test_full_fake_git_publishes_visible_tree(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = seed_remote(d)
            dl = d / "Downloads"
            dl.mkdir()
            start = time.time_ns()
            p = dl / "demo.zip"
            m = man()
            m["publish"]["files"] = [
                {
                    "source": "reply.msg",
                    "path": "mesh/ctl/DEMO-CHATGPT/reply.msg",
                    "when": "pass",
                }
            ]
            zmake(
                p,
                m,
                extra={
                    "run_tests.sh": "#!/bin/sh\nmkdir -p __pycache__\necho junk > generated.tmp\necho junk > __pycache__/junk.pyc\necho PASS\n",
                    "source.cls": "::class demo public\n",
                    "reply.msg": "EVENT|{}\n",
                },
            )
            c = a.defaults()
            c.update(root=d / "auto", repo=d / "auto" / "repo", downloads=dl, repo_url=str(remote))
            r = a.integrate(p, p.stat(), a.manifest(p), c, start)
            self.assertEqual(r["status"], "PASS")
            self.assertEqual(r["runner"]["started_ns"], start)
            self.assertEqual(r["published_tree"], "packages/demo_v0.1")
            self.assertTrue((c["repo"] / "packages/demo_v0.1/source.cls").exists())
            self.assertFalse((c["repo"] / "packages/demo_v0.1/generated.tmp").exists())
            self.assertFalse((c["repo"] / "packages/demo_v0.1/__pycache__").exists())
            self.assertTrue((c["repo"] / r["artifact_path"]).exists())
            self.assertTrue((c["repo"] / "mesh/ctl/DEMO-CHATGPT/reply.msg").exists())
            check = d / "check"
            subprocess.run(["git", "clone", str(remote), str(check)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.assertTrue((check / "packages/demo_v0.1/source.cls").exists())


    def test_git_inbox_requires_ready_marker_and_skips_receipt(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            repo = d / "repo"
            sub = repo / "autobuild/inbox/20260822T061500Z-CHATGPT-demo"
            (sub / "package").mkdir(parents=True)
            c = a.defaults()
            c["repo"] = repo
            self.assertEqual(a.git_pending_submissions(c), [])
            (sub / "ready.json").write_text(json.dumps({
                "schema": a.GIT_SUBMISSION_SCHEMA,
                "submission_id": sub.name,
                "submitted_by": "CHATGPT",
                "package_path": "package",
            }))
            self.assertEqual([p.name for p in a.git_pending_submissions(c)], [sub.name])
            receipts = repo / "autobuild/receipts"
            receipts.mkdir(parents=True)
            (receipts / (sub.name + ".json")).write_text("{}")
            self.assertEqual(a.git_pending_submissions(c), [])

    def test_git_submission_is_durable_and_runs_after_restart(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = seed_remote(d)
            seed = d / "seed"
            sid = "20260822T061600Z-CHATGPT-demo"
            sub = seed / "autobuild/inbox" / sid
            pkg = sub / "package"
            pkg.mkdir(parents=True)
            m = man()
            (pkg / "integration.json").write_text(json.dumps(m))
            (pkg / "run_tests.sh").write_text("#!/bin/sh\necho PASS\n")
            (pkg / "source.cls").write_text("::class demo public\n")
            subprocess.run(["git", "-C", str(seed), "add", str(sub.relative_to(seed) / "package")], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "stage git submission"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "push"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            (sub / "ready.json").write_text(json.dumps({
                "schema": a.GIT_SUBMISSION_SCHEMA,
                "submission_id": sid,
                "submitted_by": "CHATGPT",
                "package_path": "package",
            }))
            subprocess.run(["git", "-C", str(seed), "add", str((sub / "ready.json").relative_to(seed))], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "ready git submission"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "push"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # Deliberately choose a startup time after the submission commit. Git
            # inbox jobs are durable and are not filtered by the Downloads watermark.
            time.sleep(0.003)
            start = time.time_ns()
            c = a.defaults()
            c.update(root=d / "auto", repo=d / "auto" / "repo", repo_url=str(remote), git_poll=0.01)
            a.sync_repo(c)
            pending = a.git_pending_submissions(c)
            self.assertEqual([p.name for p in pending], [sid])
            r = a.integrate_git_submission(c, pending[0], start)
            self.assertEqual(r["status"], "PASS")
            self.assertEqual(r["source"]["kind"], "git-folder")
            self.assertEqual(r["source"]["submission_id"], sid)
            self.assertTrue((c["repo"] / "packages/demo_v0.1/source.cls").exists())
            receipt = c["repo"] / "autobuild/receipts" / (sid + ".json")
            self.assertTrue(receipt.exists())
            receipt_doc = json.loads(receipt.read_text())
            self.assertEqual(receipt_doc["status"], "PASS")
            self.assertEqual(a.git_pending_submissions(c), [])

            check = d / "check-git-inbox"
            subprocess.run(["git", "clone", str(remote), str(check)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.assertTrue((check / "packages/demo_v0.1/source.cls").exists())
            self.assertTrue((check / "autobuild/receipts" / (sid + ".json")).exists())

    def test_bad_git_submission_gets_persistent_error_receipt(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = seed_remote(d)
            seed = d / "seed"
            sid = "20260822T061700Z-CHATGPT-bad"
            sub = seed / "autobuild/inbox" / sid
            sub.mkdir(parents=True)
            (sub / "ready.json").write_text(json.dumps({
                "schema": a.GIT_SUBMISSION_SCHEMA,
                "submission_id": sid,
                "submitted_by": "CHATGPT",
                "package_path": "package",
            }))
            subprocess.run(["git", "-C", str(seed), "add", str(sub.relative_to(seed))], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "bad ready submission"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "push"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            c = a.defaults()
            c.update(root=d / "auto", repo=d / "auto" / "repo", repo_url=str(remote))
            c["root"].mkdir(parents=True)
            (c["root"] / "staging").mkdir()
            a.sync_repo(c)
            r = a.integrate_git_submission(c, a.git_pending_submissions(c)[0], time.time_ns())
            self.assertEqual(r["status"], "ERROR")
            receipt = c["repo"] / "autobuild/receipts" / (sid + ".json")
            self.assertTrue(receipt.exists())
            self.assertEqual(a.git_pending_submissions(c), [])


    def test_loop_once_pulls_ready_git_submission_without_download(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = seed_remote(d)
            seed = d / "seed"
            sid = "20260822T061800Z-CLAUDE-loop"
            sub = seed / "autobuild/inbox" / sid
            pkg = sub / "package"
            pkg.mkdir(parents=True)
            (pkg / "integration.json").write_text(json.dumps(man()))
            (pkg / "run_tests.sh").write_text("#!/bin/sh\necho PASS\n")
            (pkg / "source.cls").write_text("::class loopdemo public\n")
            (sub / "ready.json").write_text(json.dumps({
                "schema": a.GIT_SUBMISSION_SCHEMA,
                "submission_id": sid,
                "submitted_by": "CLAUDE",
                "package_path": "package",
            }))
            subprocess.run(["git", "-C", str(seed), "add", str(sub.relative_to(seed))], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "ready loop submission"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "push"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.003)
            start = time.time_ns()
            c = a.defaults()
            c.update(
                root=d / "auto",
                repo=d / "auto" / "repo",
                downloads=d / "Downloads-does-not-exist",
                repo_url=str(remote),
                git_poll=0.01,
            )
            a.loop(c, once=True, start_ns=start)
            receipt = c["repo"] / "autobuild/receipts" / (sid + ".json")
            self.assertTrue(receipt.exists())
            self.assertEqual(json.loads(receipt.read_text())["status"], "PASS")


if __name__ == "__main__":
    unittest.main()
