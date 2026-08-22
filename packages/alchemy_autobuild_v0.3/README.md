# alchemy_autobuild v0.3

Deterministic local integration relay for `animatedads/alchemy`.

There is no local LLM and no heuristic execution. The runner has two input adapters that feed the same declarative `integration.json` execution engine:

1. browser-downloaded managed ZIPs in `~/Downloads/*.zip`;
2. durable direct-Git submissions in `autobuild/inbox/<submission-id>/`.

## Defaults

- runner root: `~/alchemy-autobuild`
- download inbox: `~/Downloads`
- repository checkout: `~/alchemy-autobuild/repo`
- repository: `git@github-alchemy:animatedads/alchemy.git`
- branch: `main`
- filesystem poll: 2 seconds
- Git pull/inbox poll: 5 seconds
- Git inbox: `autobuild/inbox`
- Git receipts: `autobuild/receipts`

Authentication remains in `~/.ssh/config` through the `github-alchemy` host alias.

## Download input

At service startup the runner records a nanosecond watermark. It lists only immediate `~/Downloads/*.zip`, rejects files whose Linux `ctime_ns` predates startup, selects only the newest eligible ZIP, waits for a stable stat, and only then opens that ZIP and checks for root-level `integration.json`.

The Downloads scan is not recursive and never walks backwards through older ZIPs.

See repository `MANAGED_ZIP.md` for the producer contract.

## Direct Git input

An AI may upload a package directly to:

```text
autobuild/inbox/<submission-id>/
    package/
        integration.json
        ...source...
    ready.json
```

All package files are committed first. `ready.json` is committed last and is the atomic ready marker.

The runner periodically pulls `main` and considers only immediate inbox child directories with `ready.json`. It does not inspect an incomplete folder. A ready submission is pending until `autobuild/receipts/<submission-id>.json` exists.

Git submissions are durable: they are **not** filtered by the Downloads startup watermark. A submission made while the service is down is processed on a later service start. Ready submissions are immutable; corrections use a new submission id.

See `GIT_SUBMISSION.md` for the sender contract.

## Execution and publication

Both input adapters use the same manifest validation, environment construction, argv-only tests, timeouts, staged execution, collision-protected publication, logs, timing, and mesh result messages.

For Git submissions, `package/` is snapshotted into a deterministic ZIP before execution. This provides the same content-addressed artifact evidence as a browser-delivered ZIP.

A successful `publish.tree` is re-materialized from pristine source and promoted as ordinary Git files. Test-generated debris is never promoted. Failed tests retain evidence but do not promote source.

## Bootstrap

```sh
cd ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.3
sh bootstrap.sh
systemctl --user daemon-reload
systemctl --user enable --now alchemy-autobuild.service
```

Existing `~/alchemy-autobuild/config.json` files remain valid; v0.3 supplies defaults for the new Git inbox settings when they are absent.

Run package acceptance with:

```sh
sh run_tests.sh
```
