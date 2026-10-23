# Claude Code job: put Alchemy Autobuild back in service (v0.5.1)

**Written by:** Claude (Opus 5.5), 23 Oct 2026, for a Claude Code session on Tom's PC (any model, including Haiku).
**Architecture:** Tom Dyer. **Coding of v0.5.1:** Claude (Opus 5.5). **Earlier versions:** ChatGPT.

## What is wrong, in one paragraph

The autobuild service has not run since 22 Aug 2026. Version v0.5 crashes on start with `ModuleNotFoundError: No module named 'git_sync'`. v0.5.1 fixes that and also processes every downloaded ZIP instead of only the newest one. Your job is to install v0.5.1, prove it with one smoke ZIP while Git intake is **paused**, and then stop. Tom decides separately when the backlog of 23 waiting Git submissions may run.

## Rules

- Run only the commands in this file, in order, exactly as written.
- After each step, compare the output with **Expect**. If it does not match, **stop** and report the step number and the full output. Do not improvise a fix.
- Do not delete anything. Do not touch ED209 hosts or `sshnode.sh`. Do not run `--list-pending` with Git intake switched on.
- Do not change `"git_intake"` to `true`. Only Tom does that (section 10).

## Files Tom puts in `~/alchemy-autobuild/claude-autobuild/`

- `CLAUDE_CODE_AUTOBUILD_V051_INSTALL.md` (this file)
- `alchemy_autobuild_v0.5.1.zip`
- `alchemy_autobuild_smoke_v0.1.zip`

---

## Step 1. Check the files

```
cd ~/alchemy-autobuild
```
```
sha256sum claude-autobuild/alchemy_autobuild_v0.5.1.zip claude-autobuild/alchemy_autobuild_smoke_v0.1.zip
```

Expect exactly:
```
34969908a079d73de53843603a66670bd1dda26937b569681085e4c53b45a245  claude-autobuild/alchemy_autobuild_v0.5.1.zip
cf0716bec637f6e8340348682c965d1ad063a5c3d70f947ea8542c46eb8e0063  claude-autobuild/alchemy_autobuild_smoke_v0.1.zip
```

## Step 2. Record the current state (read-only)

Run each command and keep its full output for the report:

```
systemctl --user status alchemy-autobuild.service --no-pager
```
```
journalctl --user -u alchemy-autobuild.service -n 40 --no-pager
```
```
cat ~/.config/systemd/user/alchemy-autobuild.service
```
```
cat ~/alchemy-autobuild/runner-state.json
```
```
cat ~/alchemy-autobuild/config.json
```
```
git -C ~/alchemy-autobuild/repo status -sb
```
```
git -C ~/alchemy-autobuild/repo log -1 --format='%h %ad %s'
```
```
loginctl show-user "$USER" -p Linger
```

Expect: the service is `failed` or `activating (auto-restart)`, and the journal shows `ModuleNotFoundError: No module named 'git_sync'`. A missing unit file or missing runner-state is also fine.
**If the journal shows a different error, stop and report.** In that case the diagnosis does not match this PC.

## Step 3. Stop the crash loop and back up the old unit and config

```
systemctl --user stop alchemy-autobuild.service
```
```
cp ~/.config/systemd/user/alchemy-autobuild.service ~/alchemy-autobuild/alchemy-autobuild.service.v0.5.bak
```
```
cp ~/alchemy-autobuild/config.json ~/alchemy-autobuild/config.json.bak-20261023
```

(If the unit file or config does not exist, the `cp` fails. Note it and continue.)

## Step 4. Bring the autobuild checkout up to date

```
git -C ~/alchemy-autobuild/repo fetch origin +refs/heads/main:refs/remotes/origin/main
```
```
git -C ~/alchemy-autobuild/repo status --porcelain
```

Expect: **no output** from `status --porcelain` (a clean checkout). If there is output, stop and report it.

```
git -C ~/alchemy-autobuild/repo checkout main
```
```
git -C ~/alchemy-autobuild/repo merge --ff-only origin/main
```

Expect: `Fast-forward` or `Already up to date.` If it says the merge is not possible, stop and report.

## Step 5. Unpack v0.5.1 into the checkout

```
test ! -e ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1 && echo FREE
```

Expect: `FREE`. If nothing prints, the directory already exists: stop and report.

```
mkdir ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1
```
```
unzip -q ~/alchemy-autobuild/claude-autobuild/alchemy_autobuild_v0.5.1.zip -d ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1
```

## Step 6. Run the acceptance tests in place

```
cd ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1
```
```
sh run_tests.sh
```

Expect, near the end: `Ran 5 tests` then `OK`, followed by `Ran 3 tests` then `OK`. The tests create temporary Git repositories under `/tmp` and print some `git` push lines. That is normal: they never touch GitHub. If anything fails, stop and report.

```
cd ~/alchemy-autobuild
```

## Step 7. Commit v0.5.1 to main (bootstrap commit)

The autobuilder cannot publish its own repair while it is broken, so this one package goes in by a direct commit. This is the same bootstrap pattern MANAGED_ZIP.md describes for v0.2.

```
git -C ~/alchemy-autobuild/repo add packages/alchemy_autobuild_v0.5.1
```
```
git -C ~/alchemy-autobuild/repo -c user.name="Alchemy Autobuild" -c user.email=alchemy-autobuild@localhost commit -m "autobuild: bootstrap alchemy_autobuild v0.5.1 (service start repair, full download intake)" -m "Architecture: Tom Dyer. Coding: Claude (Opus 5.5). v0.5 could not start (ModuleNotFoundError: git_sync); no autobuild run since 20260822T065009Z."
```
```
git -C ~/alchemy-autobuild/repo push origin main
```

If the push is rejected because `main` moved, run these two commands once, then stop if they fail:
```
git -C ~/alchemy-autobuild/repo pull --rebase origin main
```
```
git -C ~/alchemy-autobuild/repo push origin main
```

## Step 8. Install the unit, pause Git intake, then start the service

```
sh ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/bootstrap.sh
```

Expect: `Installed Alchemy Autobuild v0.5.1 service definition (not started)`. If `config.json` was missing, it also prints that it created one from the v0.3 example.

```
python3 -c 'import json,pathlib; p=pathlib.Path.home()/"alchemy-autobuild/config.json"; d=json.loads(p.read_text()); d["git_intake"]=False; p.write_text(json.dumps(d,indent=2)+"\n"); print(p.read_text())'
```

Expect: the config printed with `"git_intake": false`.

```
systemctl --user daemon-reload
```
```
systemctl --user start alchemy-autobuild.service
```
```
systemctl --user status alchemy-autobuild.service --no-pager
```

Expect: `active (running)` and `alchemy_autobuild_v0.5.1` in the command line.

## Step 9. Live smoke test

Copy the smoke ZIP into Downloads **after** the service has started (only ZIPs that arrive after start are processed):

```
cp ~/alchemy-autobuild/claude-autobuild/alchemy_autobuild_smoke_v0.1.zip ~/Downloads/
```

Wait about 15 seconds, then:

```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --status
```

Expect: `"status": "pass"` and an intake.log line with `"decision": "PASS"`, `"layout": "wrapped"`.

```
git -C ~/alchemy-autobuild/repo fetch origin +refs/heads/main:refs/remotes/origin/main
```
```
git -C ~/alchemy-autobuild/repo log origin/main -2 --format='%h %ad %s'
```

Expect: the newest commit is `autobuild: <run id>`, meaning the result is on GitHub.

If the status shows `FAIL`, run the next command and include its output in the report:
```
python3 -c 'import json,pathlib,glob; r=sorted(glob.glob(str(pathlib.Path.home()/"alchemy-autobuild/repo/autobuild/results/*/result.json")))[-1]; print(r); print(json.dumps(json.load(open(r))["tests"],indent=2)[:3000])'
```

## Step 10. Stop here. List the backlog for Tom (runs nothing)

```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --list-pending
```

Put the full list in the report. **Do not enable Git intake.** Tom does that when he has reviewed the list, with these three commands:

```
python3 -c 'import json,pathlib; p=pathlib.Path.home()/"alchemy-autobuild/config.json"; d=json.loads(p.read_text()); d["git_intake"]=True; p.write_text(json.dumps(d,indent=2)+"\n")'
```
```
systemctl --user restart alchemy-autobuild.service
```
```
python3 ~/alchemy-autobuild/repo/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py --config ~/alchemy-autobuild/config.json --status
```

## Rollback (only if Tom asks)

```
systemctl --user stop alchemy-autobuild.service
```
```
cp ~/alchemy-autobuild/alchemy-autobuild.service.v0.5.bak ~/.config/systemd/user/alchemy-autobuild.service
```
```
cp ~/alchemy-autobuild/config.json.bak-20261023 ~/alchemy-autobuild/config.json
```
```
systemctl --user daemon-reload
```

(v0.5 itself does not start, so rolling back means leaving the service stopped. The v0.5.1 directory in Git is additive and is left in place.)

## Report to Tom

1. Step 1 hashes.
2. Step 2 outputs, especially the journal error line.
3. Pass or stop at each of steps 4 to 9, with output for any stop.
4. The smoke run id and the `origin/main` commit line.
5. The pending list from step 10.
6. Linger state from step 2. If it is `Linger=no`, the service only runs while Tom is logged in; Tom can change that himself with `loginctl enable-linger`.

No analysis beyond this.

Claude (Opus 5.5)
