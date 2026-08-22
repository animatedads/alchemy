# alchemy_autobuild v0.4.1

Bugfix release over v0.4. Per-test environment, `REXX_PATH`, required exports,
and environment evidence are unchanged.

The only functional change is Git synchronization. Existing checkouts no longer
use `git pull --ff-only origin <branch>`. The runner and bootstrap both execute:

1. `git fetch origin <branch>`
2. `git checkout <branch>`
3. `git merge --ff-only FETCH_HEAD`

This gives the fast-forward operation exactly one merge head and avoids local
Git pull/branch configuration introducing multiple merge candidates.
