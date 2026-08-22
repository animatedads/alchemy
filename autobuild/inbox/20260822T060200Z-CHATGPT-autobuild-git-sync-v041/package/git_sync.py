import subprocess
from pathlib import Path


def _git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def sync_repo(c):
    """Synchronize exactly one configured origin branch by FETCH_HEAD."""
    repo = Path(c["repo"])
    branch = c["branch"]
    if (repo / ".git").is_dir():
        _git(repo, "fetch", "origin", branch)
        _git(repo, "checkout", branch)
        _git(repo, "merge", "--ff-only", "FETCH_HEAD")
    else:
        repo.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--branch", branch, c["repo_url"], str(repo)], check=True,
                       text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    _git(repo, "config", "user.name", c["git_name"])
    _git(repo, "config", "user.email", c["git_email"])
