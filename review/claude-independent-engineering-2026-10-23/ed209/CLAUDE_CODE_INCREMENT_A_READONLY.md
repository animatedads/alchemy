# Claude Code job: ED209 Increment A — read-only evidence collection

**Written by:** Claude (Opus 5.5), 23 Oct 2026, for a Claude Code session running on Tom's PC (any model, including Haiku).
**Architecture:** Tom Dyer.
**Your job:** collect evidence and package it. Do **not** interpret it, fix anything or change anything. Another Claude session analyses what you collect.

---

## 1. Rules (read these first, they override everything below)

You may ONLY:
- run the commands written in this file, exactly as written;
- create files inside `~/alchemy-autobuild/claude-incA/`.

You must NOT, on any host or on this PC:
- start, stop, restart, enable, disable or kill anything (`systemctl start|stop|restart|enable|disable`, `kill`, `pkill`, `reboot`);
- copy anything TO a host (`cp`/`scp`/`rsync`/`install` through `sshnode.sh`);
- run `mu_controller_run.sh`, `run_all_20.sh`, `run_20mi.py`, `qf-xtp-rpc`, `mu-rto2-submit.rex` or any other RTO2/Grid/XTP program;
- read `node.env`, `peers.manifest`, key files or `/etc/grid/commissioning` directly (the script below reads them with secrets removed);
- edit `sshnode.sh` or any file outside `~/alchemy-autobuild/claude-incA/`;
- delete anything, anywhere. That includes the leftover patch files on ed209h;
- touch firewalls or TCP port 22.

If a command fails: write down the command and its full output, then go on to the next step. Retry a failed command **at most once**. Do not try a different command to "work around" a failure.

If you are unsure whether something is allowed, it is not allowed. Stop and ask Tom.

---

## 2. Set up (on the PC)

Tom saves the two files from this hand-off into `~/alchemy-autobuild/claude-incA/`:
- `CLAUDE_CODE_INCREMENT_A_READONLY.md` (this file)
- `ed209_readonly_snapshot.sh`

Check they are there and the script is the expected one:

```
cd ~/alchemy-autobuild
```
```
ls -l claude-incA/
```
```
sha256sum claude-incA/ed209_readonly_snapshot.sh
```

Expected: `67d69b383e121d826587f35b139b30dee6771e522b1a030b7a2bde3ae21e5497`. If it differs, stop and tell Tom: the file has been changed. Write the hash in your final report. Then check that `sshnode.sh` exists in the current directory:

```
ls -l sshnode.sh
```

If `sshnode.sh` is missing, stop and tell Tom.

---

## 3. What the snapshot script does (so you can explain it if Tom asks)

`ed209_readonly_snapshot.sh` sends one block of **read-only** commands to each host through `./sshnode.sh --job-id incA-snapshot-<host> <host> ...`, so every run appears in the sshnode log. It saves one text file per host. Covered:
- host OS, CPU, memory and virtualisation;
- QEMU binaries (`qemu-system-x86_64` versus `/usr/libexec/qemu-kvm`) and `/dev/kvm`;
- ooRexx version;
- systemd units, QEMU and XTP processes;
- network links, bridges, promiscuous flags and MTU;
- UDP 62801, raw and packet sockets, capabilities;
- Grid files with sizes and dates, plus SHA-256 hashes of binaries and images;
- MI identities (non-secret fields only), peer manifests with the key column cut out, and route tables;
- the installed RTO2 package with hashes, the `ed209-rto2-*` unit definitions and their journals since 22 Oct;
- service journals since 14 Oct.

Secrets: any run of 32 or more hex characters is replaced with `<REDACTED-HEX>` **on this PC, before the file is saved**. Lines produced by `sha256sum` are the only exception. The script uses `sudo -n` only, so it never prompts for a password. If sudo needs a password, the root-only sections come back empty; that is acceptable, so just report it.

---

## 4. Step A — snapshot F and H first

```
cd ~/alchemy-autobuild
```
```
HOSTS="ed209f ed209h" bash claude-incA/ed209_readonly_snapshot.sh
```

It prints `DONE: ed209-snapshot-<timestamp>.tar.gz`. Move the output into the job folder:

```
mv ed209-snapshot-* claude-incA/
```

## 5. Step B — snapshot the other eight MUs

```
HOSTS="ed209a ed209b ed209c ed209d ed209e ed209i ed209j ed209k" bash claude-incA/ed209_readonly_snapshot.sh
```
```
mv ed209-snapshot-* claude-incA/
```

Host names must be lowercase (`sshnode.sh` refuses `ED209A`).

## 6. Step C — local evidence on this PC (nothing is sent to any host)

C1. Hash every local copy of the RTO2 candidate scripts. This tells us which version was pushed to F on 22 Oct: the delivered candidate1 `mu-rto2-submit.rex` hashes to `4fbfeab0635256366b8199961618300862a7c2e458512c04586213215a3ae0dd`, and the sshnode log suggests a locally edited copy hashing to `c385de93bfbf8aa1088d05ff76608e545c0bdaefc0edccb3ce0dbf69c0261270` was pushed instead.

```
find ~/alchemy-autobuild -path '*ed209_rto2_20mi_candidate*' \( -name 'mu-rto2-submit.rex' -o -name 'qf-xtp-handler.rto2.rex' -o -name 'mu_controller_run.sh' \) -exec sha256sum {} + > claude-incA/local-rto2-hashes.txt 2>&1
```

C2. Package those source files, plus any local copy of the H patch script, for diffing. These are source files, not secrets:

```
find ~/alchemy-autobuild \( -path '*ed209_rto2_20mi_candidate*' \( -name 'mu-rto2-submit.rex' -o -name 'qf-xtp-handler.rto2.rex' -o -name 'mu_controller_run.sh' \) -o -name '.rto2_patch_h_handler.py' \) -print0 | tar --null -czf claude-incA/local-rto2-sources.tar.gz -T -
```

C3. Extract the 22 Oct lines from the sshnode log, with secrets redacted:

```
ls -l sshnode.log
```
```
grep -E '2026-10-22|20261022' sshnode.log | sed -E '/^[0-9a-f]{64}  \//!s/[0-9a-fA-F]{32,}/<REDACTED-HEX>/g' > claude-incA/sshnode-2026-10-22.txt
```

If `sshnode.log` is not in this folder, run `ls` and report what log files exist. Do not search the whole disk.

## 7. Step D — package and report

```
cd ~/alchemy-autobuild
```
```
tar -czf claude-incA-results.tar.gz claude-incA
```
```
ls -l claude-incA-results.tar.gz
```
```
grep -h 'exit_code=' claude-incA/ed209-snapshot-*/*.txt
```

Your final message to Tom must contain only:
1. the SHA-256 of `ed209_readonly_snapshot.sh` from section 2;
2. per host: the `exit_code` and the number of lines in its file;
3. any command that failed, with its output;
4. whether `sudo -n` worked on each host (the `sudo_noninteractive=` line near the top of each host file);
5. the path of `claude-incA-results.tar.gz`, and a request that Tom attach it to the analysing Claude session.

No analysis, no conclusions, no recommendations.

---

## 8. Not part of this job (needs Tom's explicit approval later)

- Sending any XTP packet to an MI. That includes the diagnostic `mu-xtp-diagnose.rex` PROBE, which is the next step and is prepared separately.
- Anything that changes F or H, including undoing the 22 Oct changes, stopping the temporary MI units or removing H's staging authority.

Claude (Opus 5.5)
