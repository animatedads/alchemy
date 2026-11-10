# Scotty Computer v0.1-dev6 — job evidence, scope discovery, reusable diagnostic authority

This release builds on v0.1-dev5 and retains native ooRexx IntentionService READY
and dispatch gates, the actual sshnode.sh wrapper, and single-use confirmation for
registration, revocation, privileged/effectful jobs, deployments and Git writes.

## 1. Read run evidence directly

```text
Computer 'job result RUN_ID'
Computer '--json job result RUN_ID'
Computer 'job explain RUN_ID'
Computer 'job stdout RUN_ID'
Computer 'job stderr RUN_ID'
Computer 'job history REGISTERED_JOB_NAME'
Computer '--json job history REGISTERED_JOB_NAME'
```

A confirmed execution generates mode-0600 `RUN_ID.stdout`, `RUN_ID.stderr`, and
`RUN_ID.json` files under `${XDG_CONFIG_HOME:-~/.config}/scotty-computer/jobs`.
The JSON document has `schema=scotty.computer.job-run/1`, `status`, `child_rc`,
`started_at`, `finished_at`, `elapsed_seconds`, `target`, pinned definition and
authority evidence, and private receipt paths. Reading those files performs no
command execution and needs no confirmation. `stdout`/`stderr` emit at most
64 KiB and mark truncation. `history` lists indexed dev6 runs (at most 40),
newest completion time first, with a bounded directory scan. Its `rc=1` means
no indexed runs for that name; it does not prove the job has never run.

Pre-dev6 standalone stdout/stderr receipts remain readable with their existing
run ID, including the Codex timestamped run IDs stored under `jobs/receipts/` and can be inspected through `job result`, but are explicitly
`UNKNOWN_LEGACY` with `child_rc=null`. Do not claim success from their presence.
Output may contain credentials/private data. Do not paste an entire receipt into
an unrelated log or publish it; do not put secrets into job argv.

`job result` exit 0 means *metadata was retrieved*, NOT that the child
exited successfully. To claim success check `status=EXITED` AND `child_rc=0`.
Even then, successful local/SSH process exit does not prove remote application
semantics or successful XTP packet exchange.

## 2. Discover candidate directories without searching file contents

```text
Computer 'search scopes'
Computer 'find directories matching xtp in xtpwork'
Computer '--json find directories matching xtp in xtpwork'
Computer 'add /actual/xtp/path to my find file locations as xtpsources'
Computer '--json find dependency xtp in xtpsources'
```

`find directories matching TERM in SCOPE` enumerates *only* registered
scope paths (1..N) with no global fallback, no symlink traversal and no file
contents/ZIP extraction. Results are sorted by descending filesystem mtime
and include path, UTC timestamp and match reason. Scan limits: 50,000
encountered entries, depth 16, 2,000 matching directory candidates, 40 output
records. `complete=false`, `rc=3` means the search is incomplete and the
operator must narrow the scope; do not claim not-found. No directory is
registered by discovery itself. Registration remains explicit and host-local.

## 3. Reusable authority without granting generic shell privileges

```text
Computer 'job draft diskcheck on ed209b --timeout 120 -- df -h'
Computer 'job approve REVIEW_TOKEN -- df -h'
Computer 'confirm ACTIVATION_TOKEN'
Computer 'job policy diskcheck repeat-readonly'  # preview only: rc=3
Computer 'confirm POLICY_TOKEN'                 # activate the exact policy
Computer 'job run diskcheck'                    # executes on demand under policy
Computer 'job policy diskcheck manual'          # preview removal: rc=3
Computer 'confirm POLICY_TOKEN'                 # restore per-run confirmation
```

The default remains per-execution approval, and `job draft`/`job approve`/
activation still requires operator review. `repeat-readonly` is available only
for *exact*, fixed diagnostic argument vectors: `df -h`, `df -h -T`,
`free -h`, `uname -a`, `uptime`, and `date -u`, with explicit system paths
where supported. No arbitrary paths, shell interpreters, `sudo`, `git`,
`firewall-cmd`, package installers, write operations, or other argument
variants are eligible. A policy approval is bound to the immutable job
name, definition SHA-256, resolved local executable or authoritative sshnode.sh
SHA-256, and the local SSH config hash when present. It grants no additional
OS or remote privileges and automatically fails closed when evidence changes.
Remote executable bytes/agent identities cannot be pinned by this local policy;
verify actual target and results through independent evidence.

**IMPORTANT: once this policy is active, `job run NAME` executes immediately.**
It is NOT a preview. Codex must know whether the job has repeat authority
by checking `Computer job show NAME` before invoking it; setting the policy
itself still requires a separate operator confirmation. New and all other
registered jobs continue to preview on `job run` and require a new per-run
token. Revoke with confirmed `job revoke NAME`, which also removes its repeat
policy; use `job policy NAME manual` to restore mandatory per-run approval.

There is no cryptographically independent human identity assertion in these
confirmation tokens. Codex must actually ask the user; merely presenting an
approval token does not prove a human approved it.

## 4. Qualification, status and future boundary

Use `bash tools/qualify.sh`. Tests include controlled sshnode argument recording,
local executable fixtures, positive/negative policy checks, pre-dev6 legacy
receipts, symlink/oversize rejection, bounded search, and end-to-end ooRexx
IntentionService dispatch. No live remote or firewall tests are claimed.

The proposed XTP intention family is **not yet implemented**. It must use the
existing actual XTP/SocketProvider facilities and report separate L2 local,
native L3 IPv4 protocol 36, and Google-related L4/UDP transport evidence.
Port openness is not evidence of an XTP exchange.
