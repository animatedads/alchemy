# alchemy_autobuild v0.5.2

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), 4 Nov 2026, on top of v0.5.1 (Claude) and v0.1–v0.5 (ChatGPT)
- **Written by:** Claude (Opus 5.5)

v0.5.2 fixes one defect: the runner dropped execute bits when it unpacked a package. It is additive. No earlier version's files are changed, and v0.5.1's behaviour is loaded and kept exactly.

## The defect

v0.3's `extract()` calls `zipfile.extractall()`, and `extractall()` ignores the Unix mode stored in each ZIP entry. Every layer up to v0.5.1 uses that `extract()` for both the test run and the published tree. As a result:

- a test whose argv runs a script directly fails with `Permission denied`. That covers `["./gopher"]`, and also a `run_tests.sh` that calls `tests/x.sh`;
- the tree published to `main` loses the `100755` mode the producer committed (compare `packages/alchemy_autobuild_v0.5/run_tests.sh`, which is `100644`).

The Git branch path already keeps the mode when it builds the snapshot (`materialize_package`, `deterministic_zip_tree`). Only the unpacking step lost it. A FAIL receipt is final, so before Git intake is turned on this is the difference between a valid package passing and failing for good.

Evidence: on 4 Nov 2026 the 106 Git submissions waiting on `main` and on the `autobuild-submit/*` branches were run through a local mirror of the repo. Nothing was pushed to GitHub. Under v0.5.1, `llm_gopher 0.22-dev1` failed with `./gopher: Permission denied` and the SSC machine failed with `tests/test_machine_protocol.sh: Permission denied`. Under v0.5.2 neither shows `Permission denied`: `llm_gopher` passes, and the SSC machine reaches its own test, which skips because the cloud workspace has no `rexx`. Every other outcome was the same under both versions.

## The change

`extract()` is replaced in the v0.3 engine, which every layer calls. After extraction, each regular file gets the permission bits stored in its ZIP entry:

- the low 9 bits only, so setuid, setgid and sticky are never set;
- owner read/write is always kept;
- entries with no Unix attributes, symlink entries and directories are left as before;
- the path-escape check is unchanged.

The runner state reports `intake: all-post-start-zips-oldest-first/0.5.2`, so `--status` shows which version is running.

## Acceptance

`run_tests.sh` runs v0.5.2's four tests and then v0.5.1's acceptance unchanged (5 tests), which re-runs v0.5's (3 tests).

The two file-mode tests drive the real runner against a real local Git remote, once through a downloaded ZIP and once through `tools/alchemy_submit.py`. The package runs `./run_tests.sh`, which runs `./tests/inner.sh`, and the tests check the `100755` modes in the pushed tree. Pointed at v0.5.1 instead (`AUTOBUILD_UNDER_TEST=../alchemy_autobuild_v0.5.1/alchemy_autobuild.py`), both tests fail.

## Commands

```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.2/run_tests.sh
```
```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.2/bootstrap.sh
```
```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.2/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --status
```

`bootstrap.sh` rewrites the user unit to start v0.5.2. It does not start anything and never touches `config.json`.

## Still on record

The runtime chain is now seven layers, each loading the one before by file path: v0.5.2 → v0.5.1 → v0.5 → v0.4.2 → v0.4.1 → v0.4 → v0.3. The recommendation in the v0.5.1 README stands: flatten it into a single-module v0.6. Whether to write that in ooRexx is the Architect's decision.
