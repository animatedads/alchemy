# alchemy_autobuild v0.5.3

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), 14 Nov 2026, on top of v0.5.2 and v0.5.1 (Claude) and v0.1–v0.5 (ChatGPT)
- **Written by:** Claude (Opus 5.5)

v0.5.3 makes one change: every package runs the ooRexx **Python gate** (`packages/oorexx_python_gate_v0.1`) before its own tests. A package that carries Python, or calls Python, without a `PYTHON_JUSTIFICATION` entry for it FAILS, and is not published. It is additive: no earlier version's files are changed.

## Why

Asked to read a file, a model reaches for Python, then wraps it in two lines of Rexx and calls the result ooRexx. Arguing about it chat by chat doesn't stop it; a build gate does. The gate cannot judge whether a reason is good. It makes each reason visible in the build log for the VERIFIER and the Architect. "Reading a file is complex" does not count as a reason.

## How it hooks in

The gate is test 01 of every run, named `python-justification-gate`. Its JSON report and progress log are in the result and receipt like any other test log.

Both intake paths reach v0.3 `integrate()` through v0.4's module global `_base_integrate`. These are the ZIP path (v0.5.1 `process_zip`) and the branch path (v0.5 `_integrate_branch`, which calls v0.4.2 `integrate` directly and so would bypass a patch of `_v3.integrate`). v0.5.3 wraps that one global. v0.4 matches per-test environment specs to tests by position, so the wrapper also puts an empty spec in front for the gate.

## Config (`config.json`, all optional)

| key | default | meaning |
|---|---|---|
| `python_gate` | `"enforce"` | `"advisory"`: the gate runs and logs, and never fails a package |
| `python_gate_script` | the copy in the service's repo checkout | path to `python_gate.rex` |
| `rexx` | `"rexx"` | the interpreter. Under systemd, give an absolute path |

If the gate cannot run (no `rexx`, script missing), the gate test FAILS. An unavailable check is NOT RUN, never PASS.

## Blast radius (measured 14 Nov 2026, `main` at `183da160`)

The gate was run over all 497 directories under `packages/`. **317 pass and 180 fail.** There are 1,109 Python files with no justification, plus 148 files that call Python (342 call lines in shell scripts, 24 in Rexx). Nothing is justified yet. The gate only judges new submissions, but a resubmitted package that still carries Python will FAIL. `"advisory"` is there for a staged roll-out if the Architect wants one.

## Acceptance

`run_tests.sh` runs the gate's 23 ooRexx tests, then v0.5.3's 9 runner tests, then v0.5.2's acceptance unchanged. The runner tests drive the real runner against a real local Git remote and the real gate:

- a clean ooRexx package passes, with the gate first;
- Tom's `rexx.app` parody (`"python3 codehehe.py"`) FAILS and is not published;
- a justified `.py` passes, and its reason is in the log;
- in advisory mode, the run logs FAIL but still passes;
- a missing gate script fails closed;
- a bad mode is rejected at start;
- per-test environments still line up;
- a Git branch submission is gated too;
- the service state names 0.5.3 and the mode.

Pointed at v0.5.2 instead (`AUTOBUILD_UNDER_TEST=../alchemy_autobuild_v0.5.2/alchemy_autobuild.py`), 8 of the 9 fail.

## Commands

```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/run_tests.sh
```
```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/bootstrap.sh
```

`bootstrap.sh` rewrites the user unit to start v0.5.3. It refuses to install unless the gate and `rexx` are present, starts nothing, and never touches `config.json`.

The install procedure, written so that any model including Haiku can follow it, is `docs/autobuild/INSTALL_V053_WITH_CLAUDE_CODE.md`. It installs in advisory mode first, because a FAIL receipt is final. Config changes go through `tools/autobuild_config.rex`, written in ooRexx, which replaces the `python3 -c` one-liners of the v0.5.1 procedure. It refuses unknown keys and bad modes, and `set rexx auto` stores the absolute path of `rexx` for systemd.

## Still on record

This package is itself Python; see `PYTHON_JUSTIFICATION`. The chain is now eight layers. The case for one flattened v0.6, in ooRexx, is stronger with every layer.
