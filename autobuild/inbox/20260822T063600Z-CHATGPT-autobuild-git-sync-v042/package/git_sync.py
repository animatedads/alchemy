import subprocess
from pathlib import Path


def _git(repo, *args):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def sync_repo(c):
    """Synchronize exactly one configured origin branch by named remote ref.

    Do not use git pull or FETCH_HEAD: FETCH_HEAD may contain multiple entries
    under legitimate local Git configuration.  Fetch the one branch into its
    one remote-tracking ref, then fast-forward to that explicit ref.
    """
    repo = Path(c["repo"])
    branch = c["branch"]
    remote_ref = f"refs/remotes/origin/{branch}"
    fetch_refspec = f"+refs/heads/{branch}:{remote_ref}"
    if (repo / ".git").is_dir():
        _git(repo, "fetch", "origin", fetch_refspec)
        _git(repo, "checkout", branch)
        _git(repo, "merge", "--ff-only", remote_ref)
    else:
        repo.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["git", "clone", "--branch", branch, c["repo_url"], str(repo)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    _git(repo, "config", "user.name", c["git_name"])
    _git(repo, "config", "user.email", c["git_email"])
