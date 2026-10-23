# alchemy_autobuild v0.5.1

**Architecture:** Tom Dyer. **Coding:** Claude (Opus 5.5), 23 Oct 2026, on top of ChatGPT's v0.1–v0.5.

v0.5.1 repairs the autobuilder and makes it usable for the way packages actually arrive. It is additive: no earlier version's files are changed, and v0.5's branch-inbox behaviour is loaded and kept exactly.

## Why the autobuilder went silent on 22 Aug 2026

v0.5 could not start as a service. Its entry point loads v0.4.2 by file path, and v0.4.2 runs `from git_sync import sync_repo`. But `git_sync.py` lives in v0.4.2's directory, and Python only searches the running script's directory (v0.5's). Every start died with `ModuleNotFoundError: No module named 'git_sync'`. With `Restart=on-failure` and `RestartSec=2`, systemd's start limit then left the unit failed, with nothing in Git to show it.

v0.5 was still accepted, because its acceptance test only imported `branch_inbox` and never started the program. The last autobuild result in Git is `20260822T065009Z`, the run that published v0.5. Every branch submission and download since then went unprocessed; some October work reached `main` by manual merge with no receipt.

## What v0.5.1 changes

| Change | Before | v0.5.1 |
|---|---|---|
| Service start | Dies on import | Puts the v0.5 and v0.4.2 directories on `sys.path` before loading. That is the import environment the accepted v0.4.2 service ran with. |
| Download batch | Only the newest post-start ZIP is considered; earlier downloads are silently skipped forever | Every post-start ZIP is processed, oldest first, exactly once, after being stable for two polls |
| ZIP wrapped in one folder (`pkg_v1/integration.json`) | Ignored as "no manifest" | Re-rooted into a deterministic snapshot and integrated. The result records `kind=zip-wrapped`, `wrapper_dir` and the original filename and SHA-256 |
| ZIP with no `integration.json` | Silent local state only | Never integrated; one JSON line in `~/alchemy-autobuild/intake.log` |
| Visibility | `runner-state.json` only | `--status` (state plus recent intake) and `--list-pending` (Git submissions that would run, without running them) |
| Controlled start | Git backlog runs immediately | `"git_intake": false` in `config.json` pauses the Git inbox. Default is `true`. |
| systemd | Start limit could leave the unit dead | `StartLimitIntervalSec=0`, `RestartSec=10` |
| Acceptance | Never started the program | Starts the exact `ExecStart` form, drives download and branch intake end to end against a real local Git remote, then re-runs v0.5's tests |

The new startup test fails on v0.5 with the exact `ModuleNotFoundError` and passes on v0.5.1.

## Commands

```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --status
```
```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --list-pending
```
```
systemctl --user status alchemy-autobuild.service
```

## Rules for producers (ChatGPT, Codex, Claude, Gemini)

1. Every package carries `integration.json`. At the ZIP root is preferred; one wrapping folder is now accepted.
2. Normal source packages declare `publish.tree` with a versioned path under `packages/`. `artifact_only` means the source will **never** reach Git; use it only for genuine test payloads. XTP dev25 and Storage Fabric dev23 were both submitted as `artifact_only`.
3. Tests are argv arrays that run locally and unattended: no `sshnode.sh`, no fleet hosts, no `sudo`. The autobuilder runs them as the operator, with the operator's credentials.
4. With a Git checkout, use `tools/alchemy_submit.py --submitted-by <NAME>`. Without one, hand the ZIP to Tom to download into `~/Downloads` while the service is running.
5. A receipt in `autobuild/receipts/` is the only evidence of integration. A merge to `main` is not.

## Why this is still Python

The autobuilder is build and orchestration tooling, which is a legitimate role for Python under the Alchemy policy. v0.1–v0.5 are Python, and v0.5.1 is a repair, not a rewrite. Rewriting it in ooRexx is a separate decision for the Architect. One structural weakness should be on record: the runtime is a five-layer chain that loads each older version by file path and patches its globals (v0.5.1 → v0.5 → v0.4.2 → v0.4.1 → v0.4 → v0.3). It works, but any change to an older directory changes the live service. A flattened single-module v0.6 is recommended.
