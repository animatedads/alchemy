# alchemy_autobuild v0.4.2

Bugfix release for Git synchronization. It retains the v0.4 per-test environment/REXX_PATH contract and the v0.4.1 architecture, but removes FETCH_HEAD from synchronization decisions.

For an existing checkout it executes the equivalent of:

```sh
git fetch origin +refs/heads/main:refs/remotes/origin/main
git checkout main
git merge --ff-only refs/remotes/origin/main
```

The configured branch is substituted for `main` at runtime. `git pull` and `FETCH_HEAD` are deliberately not used.

This prevents local Git configurations that leave multiple FETCH_HEAD entries from producing `fatal: Cannot fast-forward to multiple branches.`
