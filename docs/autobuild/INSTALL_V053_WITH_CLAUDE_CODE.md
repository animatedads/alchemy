# Claude Code job: start Alchemy Autobuild v0.5.3 (the Python gate)

**Written by:** Claude (Opus 5.5), 14 Nov 2026, for a Claude Code session on the build host (any model, including Haiku).
**Architecture:** Tom Dyer. **v0.5.3, gate and config tool coding:** Claude (Opus 5.5). **Earlier versions:** ChatGPT and Claude.

## What this does

v0.5.3 runs the ooRexx Python gate (`packages/oorexx_python_gate_v0.1`) as test 01 of every package. This job:

1. checks that v0.5.3 is on `main` and that `rexx` works;
2. runs the v0.5.3 tests in the autobuild checkout;
3. installs v0.5.3 with the gate in **advisory** mode;
4. checks the running service.

Then it stops. Only Tom switches the gate to **enforce** (step 9).

**Why advisory first:** a FAIL receipt is final. On `main` today, 180 of 497 packages would fail the gate. Advisory logs every finding and fails nothing, so Tom sees the effect before turning it on.

## Rules

- Run only the commands in this file, in order, exactly as written.
- After each step, compare with **Expect**. If it does not match, **stop** and report the step number and the full output.
- Do not delete anything. Do not touch ED209 hosts or `sshnode.sh`.
- Work only in `~/alchemy-autobuild`. Do not edit, commit or branch in `~/alchemy-autobuild/repo`: that checkout belongs to the Autobuild service.
- Do not change `git_intake`. Do not set `python_gate` to `enforce`. Only Tom does those.

## Step 0. Precondition

PR #146 (`claude/python-gate-rc-tools-win-resources-20261114`) must be merged to `main`. If Tom has not said it is merged, stop here.

## Step 1. Record the current state (read-only)

```
systemctl --user status alchemy-autobuild.service --no-pager
```
```
cat ~/alchemy-autobuild/runner-state.json
```
```
git -C ~/alchemy-autobuild/repo status --porcelain
```

Expect:
- The service is `active (running)` or `inactive`. Note which version its command line names.
- `runner-state.json` shows an `intake` ending in the version, e.g. `/0.5.2`.
- `status --porcelain` prints nothing.

If `status --porcelain` prints anything, stop and report.

## Step 2. Bring the checkout to main

```
git -C ~/alchemy-autobuild/repo fetch origin +refs/heads/main:refs/remotes/origin/main
```
```
git -C ~/alchemy-autobuild/repo checkout main
```
```
git -C ~/alchemy-autobuild/repo merge --ff-only origin/main
```
```
test -f ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/alchemy_autobuild.py && echo V053_PRESENT
```
```
test -f ~/alchemy-autobuild/repo/packages/oorexx_python_gate_v0.1/bin/python_gate.rex && echo GATE_PRESENT
```

Expect: `Fast-forward` or `Already up to date.`, then `V053_PRESENT`, then `GATE_PRESENT`.

## Step 3. Check the kit

```
command -v rexx
```
```
rexx -v
```
```
command -v python3 git
```

Expect: a path for `rexx`, then `Open Object Rexx Version 5.3.0`, then a path for each of `python3` and `git`. If `rexx` is missing, stop: without it, every package would FAIL.

## Step 4. Run the v0.5.3 tests in the checkout

```
cd ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3
```
```
sh run_tests.sh
```
```
cd ~/alchemy-autobuild
```

Expect, in this order:
1. `python_gate tests: 23 passed, 0 failed`
2. `autobuild_config tests: 10 passed, 0 failed`
3. `Ran 9 tests` then `OK`
4. `Ran 4 tests` then `OK`
5. `Ran 5 tests` then `OK`
6. `Ran 3 tests` then `OK`

The tests use temporary Git repositories under `/tmp` and never touch GitHub.

## Step 5. Back up the unit and the config

```
cp ~/.config/systemd/user/alchemy-autobuild.service ~/alchemy-autobuild/alchemy-autobuild.service.bak-20261114
```
```
cp ~/alchemy-autobuild/config.json ~/alchemy-autobuild/config.json.bak-20261114
```

## Step 6. Set the gate to advisory, and give the service the absolute path of rexx

```
rexx ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/tools/autobuild_config.rex set python_gate advisory
```
```
rexx ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/tools/autobuild_config.rex set rexx auto
```
```
rexx ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/tools/autobuild_config.rex show
```

Expect: `python_gate was (absent) now advisory`, then `rexx was (absent) now /…/rexx`, then the config showing both. `git_intake` must be unchanged from step 1.

## Step 7. Install and restart

```
systemctl --user stop alchemy-autobuild.service
```
```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/bootstrap.sh
```
```
systemctl --user daemon-reload
```
```
systemctl --user start alchemy-autobuild.service
```
```
systemctl --user status alchemy-autobuild.service --no-pager
```

Expect: `Installed Alchemy Autobuild v0.5.3 service definition (not started)`, then `active (running)`, with `alchemy_autobuild_v0.5.3` in the command line.

## Step 8. Check the running service and stop

```
cat ~/alchemy-autobuild/runner-state.json
```

Expect: `"intake": "all-post-start-zips-oldest-first/0.5.3"` and `"python_gate": "advisory"`. Report steps 1–8 to Tom and stop.

## Step 9. Tom only: enforce the gate

```
rexx ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.3/tools/autobuild_config.rex set python_gate enforce
```
```
systemctl --user restart alchemy-autobuild.service
```

## Rollback

```
systemctl --user stop alchemy-autobuild.service
```
```
cp ~/alchemy-autobuild/alchemy-autobuild.service.bak-20261114 ~/.config/systemd/user/alchemy-autobuild.service
```
```
cp ~/alchemy-autobuild/config.json.bak-20261114 ~/alchemy-autobuild/config.json
```
```
systemctl --user daemon-reload
```
```
systemctl --user start alchemy-autobuild.service
```
