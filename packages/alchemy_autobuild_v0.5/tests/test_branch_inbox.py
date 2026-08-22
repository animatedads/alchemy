import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from branch_inbox import pending_submissions, read_ready, materialize_package


def git(*args, cwd=None):
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout.strip()


def seed(d):
    remote = d / "remote.git"
    seed = d / "seed"
    git("init", "--bare", str(remote))
    git("clone", str(remote), str(seed))
    git("config", "user.email", "x@y", cwd=seed)
    git("config", "user.name", "x", cwd=seed)
    (seed / "README").write_text("seed\n")
    git("add", "README", cwd=seed)
    git("commit", "-m", "seed", cwd=seed)
    git("branch", "-M", "main", cwd=seed)
    git("push", "-u", "origin", "main", cwd=seed)
    git("--git-dir", str(remote), "symbolic-ref", "HEAD", "refs/heads/main")
    return remote, seed


class T(unittest.TestCase):
    def test_branch_submission_found_without_checkout_and_binary_materializes(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote, seedrepo = seed(d)
            sid = "SID-1"
            git("switch", "-c", "ai/submission", cwd=seedrepo)
            base = seedrepo / "autobuild/inbox" / sid
            (base / "package").mkdir(parents=True)
            (base / "package/integration.json").write_text(
                '{"schema":"alchemy.autobuild.integration/0.3"}'
            )
            (base / "package/x.bin").write_bytes(b"\x00\xffx")
            git("add", str(base.relative_to(seedrepo) / "package"), cwd=seedrepo)
            git("commit", "-m", "body", cwd=seedrepo)
            (base / "ready.json").write_text(
                json.dumps(
                    {
                        "schema": "alchemy.autobuild.git-submission/0.1",
                        "submission_id": sid,
                        "submitted_by": "CHATGPT",
                        "package_path": "package",
                    }
                )
            )
            git("add", str((base / "ready.json").relative_to(seedrepo)), cwd=seedrepo)
            git("commit", "-m", "ready", cwd=seedrepo)
            git("push", "origin", "ai/submission", cwd=seedrepo)

            repo = d / "runner"
            git("clone", str(remote), str(repo))
            head_before = git("rev-parse", "HEAD", cwd=repo)
            branch_before = git("branch", "--show-current", cwd=repo)
            pending = pending_submissions(repo)
            self.assertEqual([x.name for x in pending], [sid])
            doc = read_ready(repo, pending[0])
            self.assertEqual(doc["submission_id"], sid)
            out = d / "out"
            materialize_package(repo, pending[0], "package", out)
            self.assertEqual((out / "x.bin").read_bytes(), b"\x00\xffx")
            self.assertEqual(git("rev-parse", "HEAD", cwd=repo), head_before)
            self.assertEqual(git("branch", "--show-current", cwd=repo), branch_before)

    def test_inherited_main_ready_is_not_treated_as_branch_submission(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote, seedrepo = seed(d)
            sid = "OLD"
            base = seedrepo / "autobuild/inbox" / sid
            base.mkdir(parents=True)
            (base / "ready.json").write_text("{}")
            git("add", "autobuild", cwd=seedrepo)
            git("commit", "-m", "old ready", cwd=seedrepo)
            git("push", cwd=seedrepo)
            git("switch", "-c", "ai/no-new-ready", cwd=seedrepo)
            (seedrepo / "unrelated").write_text("x")
            git("add", "unrelated", cwd=seedrepo)
            git("commit", "-m", "x", cwd=seedrepo)
            git("push", "origin", "ai/no-new-ready", cwd=seedrepo)
            repo = d / "runner"
            git("clone", str(remote), str(repo))
            self.assertEqual(pending_submissions(repo), [])

    def test_receipt_suppresses_branch_submission(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote, seedrepo = seed(d)
            sid = "SID-2"
            git("switch", "-c", "ai/submission2", cwd=seedrepo)
            base = seedrepo / "autobuild/inbox" / sid
            (base / "package").mkdir(parents=True)
            (base / "package/integration.json").write_text("{}")
            (base / "ready.json").write_text("{}")
            git("add", "autobuild", cwd=seedrepo)
            git("commit", "-m", "ready", cwd=seedrepo)
            git("push", "origin", "ai/submission2", cwd=seedrepo)
            repo = d / "runner"
            git("clone", str(remote), str(repo))
            rec = repo / "autobuild/receipts"
            rec.mkdir(parents=True)
            (rec / (sid + ".json")).write_text("{}")
            self.assertEqual(pending_submissions(repo), [])


if __name__ == "__main__":
    unittest.main()
