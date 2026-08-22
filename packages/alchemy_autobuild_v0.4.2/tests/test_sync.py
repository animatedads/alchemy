import subprocess
import tempfile
import unittest
from pathlib import Path

from git_sync import sync_repo


class SyncTests(unittest.TestCase):
    def test_named_remote_ref_fast_forward_ignores_fetch_head_multiplicity(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = d / "remote.git"
            seed = d / "seed"
            work = d / "work"
            subprocess.run(["git", "init", "--bare", str(remote)], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "clone", str(remote), str(seed)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for repo in (seed,):
                subprocess.run(["git", "-C", str(repo), "config", "user.name", "test"], check=True)
                subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"], check=True)
            (seed / "x.txt").write_text("one\n")
            subprocess.run(["git", "-C", str(seed), "add", "x.txt"], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "one"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "branch", "-M", "main"], check=True)
            subprocess.run(["git", "-C", str(seed), "push", "-u", "origin", "main"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "--git-dir", str(remote), "symbolic-ref", "HEAD", "refs/heads/main"], check=True)
            subprocess.run(["git", "clone", "--branch", "main", str(remote), str(work)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            (seed / "x.txt").write_text("two\n")
            subprocess.run(["git", "-C", str(seed), "add", "x.txt"], check=True)
            subprocess.run(["git", "-C", str(seed), "commit", "-m", "two"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(seed), "push"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # Put multiple lines into FETCH_HEAD deliberately. sync_repo must not
            # consult it; it must fast-forward to refs/remotes/origin/main.
            subprocess.run(["git", "-C", str(work), "fetch", "origin", "main", "master"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            c = {
                "repo": work,
                "branch": "main",
                "repo_url": str(remote),
                "git_name": "Alchemy Autobuild",
                "git_email": "alchemy-autobuild@localhost",
            }
            sync_repo(c)
            self.assertEqual((work / "x.txt").read_text(), "two\n")


if __name__ == "__main__":
    unittest.main()
