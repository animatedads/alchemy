import subprocess
import tempfile
import unittest
from pathlib import Path
from git_sync import sync_repo


def git(*argv, cwd=None, quiet=False):
    return subprocess.run(["git", *argv], cwd=cwd, check=True, text=True,
                          stdout=subprocess.DEVNULL if quiet else subprocess.PIPE,
                          stderr=subprocess.DEVNULL if quiet else subprocess.PIPE)


class SyncRegressionTests(unittest.TestCase):
    def test_bootstrap_uses_fetch_head_not_pull(self):
        text = (Path(__file__).parents[1] / "bootstrap.sh").read_text()
        self.assertNotIn("git -C \"$REPO\" pull", text)
        self.assertIn('git -C "$REPO" fetch origin "$BRANCH"', text)
        self.assertIn('git -C "$REPO" merge --ff-only FETCH_HEAD', text)

    def test_sync_repo_fast_forwards_exact_fetched_branch(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            remote = d / "remote.git"; seed = d / "seed"; root = d / "auto"; repo = root / "repo"
            git("init", "--bare", str(remote), quiet=True)
            git("clone", str(remote), str(seed), quiet=True)
            git("config", "user.name", "seed", cwd=seed); git("config", "user.email", "seed@example.invalid", cwd=seed)
            (seed / "one").write_text("1"); git("add", "one", cwd=seed); git("commit", "-m", "one", cwd=seed, quiet=True)
            git("branch", "-M", "main", cwd=seed); git("push", "-u", "origin", "main", cwd=seed, quiet=True)
            git("--git-dir", str(remote), "symbolic-ref", "HEAD", "refs/heads/main")
            c = {"root": root, "repo": repo, "repo_url": str(remote), "branch": "main", "git_name": "test", "git_email": "test@example.invalid"}
            sync_repo(c)
            (seed / "two").write_text("2"); git("add", "two", cwd=seed); git("commit", "-m", "two", cwd=seed, quiet=True); git("push", cwd=seed, quiet=True)
            git("config", "--add", "branch.main.merge", "refs/heads/unrelated", cwd=repo)
            sync_repo(c)
            self.assertEqual((repo / "two").read_text(), "2")


if __name__ == "__main__": unittest.main()
