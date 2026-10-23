# Claude Code job: start Alchemy Autobuild v0.5.1 from main

**Written by:** Claude (Opus 5.5), 23 Oct 2026, for a Claude Code session on Tom's PC (any model, including Haiku).
**Architecture:** Tom Dyer. **v0.5.1 coding:** Claude (Opus 5.5). **Earlier versions:** ChatGPT.

## What this does

v0.5.1 is already on `main` at `packages/alchemy_autobuild_v0.5.1`. This job:

1. pulls `main` into the autobuild checkout;
2. proves v0.5.1 starts and passes its tests there;
3. installs and starts the service with Git intake **paused**;
4. proves it with one smoke ZIP.

Then it stops. Tom decides when the Git backlog may run.

## Rules

- Run only the commands in this file, in order, exactly as written.
- After each step, compare with **Expect**. If it does not match, **stop** and report the step number and the full output.
- Do not delete anything. Do not touch ED209 hosts or `sshnode.sh`.
- Do not set `"git_intake"` to `true`. Only Tom does that (step 8).

## Step 1. Record the current state (read-only)

```
systemctl --user status alchemy-autobuild.service --no-pager
```
```
journalctl --user -u alchemy-autobuild.service -n 40 --no-pager
```
```
git -C ~/alchemy-autobuild/repo status --porcelain
```
```
git -C ~/alchemy-autobuild/repo log -1 --format='%h %ad %s'
```

Expect:
- The service is `failed`, `activating (auto-restart)`, or not installed.
- If installed, the journal shows `ModuleNotFoundError: No module named 'git_sync'`.
- `status --porcelain` prints nothing.

If the journal shows a different error, or `status --porcelain` prints anything, stop and report.

## Step 2. Stop the crash loop and back up the unit and config

```
systemctl --user stop alchemy-autobuild.service
```
```
cp ~/.config/systemd/user/alchemy-autobuild.service ~/alchemy-autobuild/alchemy-autobuild.service.v0.5.bak
```
```
cp ~/alchemy-autobuild/config.json ~/alchemy-autobuild/config.json.bak-20261023
```

(A `cp` of a file that does not exist fails. Note it and continue.)

## Step 3. Bring the checkout to main

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
test -f ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py && echo PRESENT
```

Expect: `Fast-forward` or `Already up to date.`, then `PRESENT`.

## Step 4. Run the v0.5.1 tests in the checkout

```
cd ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1
```
```
sh run_tests.sh
```
```
cd ~/alchemy-autobuild
```

Expect: `Ran 5 tests` then `OK`, followed by `Ran 3 tests` then `OK`. The tests use temporary Git repositories under `/tmp` and never touch GitHub.

## Step 5. Install the unit, pause Git intake, start the service

```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/bootstrap.sh
```
```
python3 -c 'import json,pathlib; p=pathlib.Path.home()/"alchemy-autobuild/config.json"; d=json.loads(p.read_text()); d["git_intake"]=False; p.write_text(json.dumps(d,indent=2)+"\n"); print(p.read_text())'
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

Expect: `Installed Alchemy Autobuild v0.5.1 service definition (not started)`, then the config with `"git_intake": false`, then `active (running)` with `alchemy_autobuild_v0.5.1` in the command line.

## Step 6. Smoke test

Tom places `alchemy_autobuild_smoke_v0.1.zip` (from the 23 Oct hand-off) in `~/alchemy-autobuild/claude-autobuild/`. Then:

```
cp ~/alchemy-autobuild/claude-autobuild/alchemy_autobuild_smoke_v0.1.zip ~/Downloads/
```

Wait 15 seconds, then:

```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --status
```

Expect: `"status": "pass"`, and an intake line with `"decision": "PASS"` and `"layout": "wrapped"`.

## Step 7. List the Git backlog (runs nothing) and stop

```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --list-pending
```

Report the list. Most of it was published to `main` by hand on 23 Oct (see `autobuild/manual-publication/2026-10-23.json`). When autobuild later runs those submissions, publication to an identical existing path is a no-op and a receipt is written.

## Step 8. Tom only: enable Git intake

```
python3 -c 'import json,pathlib; p=pathlib.Path.home()/"alchemy-autobuild/config.json"; d=json.loads(p.read_text()); d["git_intake"]=True; p.write_text(json.dumps(d,indent=2)+"\n")'
```
```
systemctl --user restart alchemy-autobuild.service
```

## Report to Tom

Report the step 1 outputs, pass or stop at each step, the smoke run id, and the pending list. Include the `Linger=` value from the next command; `Linger=no` means the service runs only while Tom is logged in.

```
loginctl show-user "$USER" -p Linger
```

Claude (Opus 5.5)
