# Scotty Computer — v0.1-dev9

**Executable:** `Computer` (real ooRexx, no filename suffix), retaining the user's source file name and semantics. The supplied original was a 3-line `parse arg; say` stub. It is now an ooRexx IntentionService client.

## Dev7 — job-scoped expected exceptions and Claude Code qualification

- Register expected exception conditions *against an existing job*: `Computer 'job exception register NAME runaway_space /tmp/workspace 10 meg'`; `runtime_overrun N seconds`; `output_contains "ERROR:" stdout|stderr|both`. Registration itself is previewed and separately confirmed. `Computer 'job exceptions NAME'` lists the current rules.
- Start with `Computer 'job run NAME'` or `Computer 'job start NAME'` (both issue an execution preview unless a separately-approved repeat-readonly policy applies). At execution the registered rule set is snapshotted and checked only during the job. A 10-meg limit triggers at 11,000,000 observed apparent regular-file bytes; no external monitor or follow-on task runs. The first breach and any observation failure are preserved in run metadata; checks do not terminate a job. Exit 6 reports a raised exception or incomplete observation, independently of `child_rc`.
- Corrected `BrokenPipeError` on early-closing consumers such as `grep -q`/`head`; isolated Git transport tests from host `url.insteadOf`; added `CLAUDE.md`, optional project-local Claude Code `.claude/settings.json` PreToolUse permission hook, and a Computer skill. The hook requests permission, **not** independently verifiable approver identity, and is only active when the project configuration is loaded.
- See `docs/JOB_EXCEPTIONS.md` and `CLAUDE.md`. Remote `runaway_space` is blocked until a remote-side measuring capability is commissioned. No live ED209 operations are implied by local tests.

## Dev6 — reusable diagnostic authority, job receipts and directory discovery

- Direct receipt intentions: `Computer job result|stdout|stderr|explain RUN_ID`, `Computer job history NAME`, and `--json` for structured result/history. Every dev6 run stores a private JSON record with the exact child exit code. Older stdout/stderr receipts are labeled `UNKNOWN_LEGACY`, never implied success.
- Scope-guided directory lookup: `Computer find directories matching xtp in xtpwork`, newest directory candidates first, with no file scan, ZIP extraction, symlink traversal, or fallback outside registered scopes. Exceeded budgets return incomplete, nonzero.
- Explicit reusable diagnostic policy: `Computer job policy NAME repeat-readonly` previews and requires confirmation. Only fixed `df`/`free`/`uptime`/`uname`/`date` diagnostics are eligible. With the policy activated `Computer job run NAME` **executes immediately**, rechecking pinned definition/executable/sshnode and SSH config identity; no new OS privilege is gained. Other jobs remain per-execution confirmed. `job policy NAME manual` and `job revoke NAME` can remove this authority, subject to confirmation.
- Source and acceptance: `docs/JOB_EVIDENCE_SCOPE_POLICY.md`, `tests/test_dev6.py`, `tests/test_oorexx_dev6.sh`.

## Dev5 — governed executable jobs and read-only documents

- `Computer job draft NAME local|on ed209NODE [--cwd LOCAL_DIR] [--timeout SECONDS] -- EXEC ARGS...` proposes a reusable, immutable **real command**, local or remote, without executing it. Native IntentionService dispatch is retained; no shell eval for local execution. For remote execution the existing `sshnode.sh` is used with a quoted single remote-shell command.
- `Computer job approve REVIEW_TOKEN -- EXEC ARGS...` proves exactly the proposed executable, argument values and ordering. A **separate** `Computer confirm TOKEN` activates the definition.
- `Computer job run NAME` previews a single run. A **new** `Computer confirm TOKEN` executes it, after rechecking the executable or SSH adapter SHA-256, and stores mode-0600 stdout/stderr receipts and recorded exit status. `COMPUTER_DRY_RUN=1` consumes approval but performs no execution.
- `Computer job list` / `Computer job show NAME` inspect registered job definitions. `Computer job revoke NAME` previews revocation and requires a separate confirm; it invalidates pending executions. Registration does not modify privileges or replace SSH keys. A shell (`bash -c`, etc.) can be intentionally registered, but this is explicitly a command to run under normal account permissions and must be reviewed as such.
- `Computer read document FILE` and `Computer list documents in ZIP` / `Computer read document MEMBER in ZIP` provide read-only, bounded UTF-8/source document inspection without extraction: 1 MiB document, 256 MiB archive, 10,000 entries. Exact member path required; symlinks and ambiguous members rejected.
- Dedicated tests: `tests/test_jobs.py`, `tests/test_documents.py`, `tests/test_oorexx_jobs_documents.sh`. See `docs/EXECUTABLE_JOB_INTENTIONS.md` for the exact Codex protocol and limitations.

## Architecture

1. `Computer` constructs an **IntentionService v0.1-dev11**, registers an explicit intention bucket, a dynamic `ComputerDiscovery` source and a gated event executor.
2. On *each* input invocation, IntentionService calls `refreshDiscovery` and advertises transient `COMPUTER.LOCAL` surfaces when the installed backend is present. SSH capability is offered only when a local `sshnode.sh` adapter is discoverable. Capabilities are independently checked again by the action executor.
3. `ComputerIntentionProvider` proposes an intention, its explicit source utterance and an `IntentionPlan` side-effect class. Only a `READY` decision can go through `IntentionService~dispatch`.
4. `ComputerActions.py` is a bounded local executor, not an NLP engine. The ooRexx caller sends text as **hex**, never as shell source, and the Python executor revalidates intention grammar, filesystem and adapter authority. Effectful helpers are called as subprocess argv arrays, never `shell=True`.
5. Durable user-local state lives at `${XDG_CONFIG_HOME:-~/.config}/scotty-computer/state.json`, and **content-blind** audit events at `audit.jsonl`. Both are mode 0600; config directory mode 0700. Text is represented in the audit log only by SHA-256 (not the utterance).

The semantic core remains the original **Intention Service**; this package does not invent an alternative intention engine, transport, or cloud API. The `ComputerIntentionProvider` is a **bounded bootstrapping grammar for the explicitly requested phrases**, not a claim to general open-ended NL intent understanding. Domain specialists may contribute additional dynamic discovery surfaces in a subsequent release. The separate Management Intention Discovery dev8 framework was inspected, but is **not embedded or claimed as integrated** in this delivery: its responsibility for relationship traversal is outside this initial local Computer domain.

## Dev4: GitHub, named search scopes, governed learning

- Machine-local **named search scopes** map a stable `inboundfiles` or `dependencies` label to one or more existing directories. Searches **must name** their scope; results include timestamps, exact paths, sizes, SHA-256 evidence status, match reason and ZIP-member names without extraction. Unknown scopes never fall back to unrelated roots.
- GitHub operations: inspect configured SSH host aliases (`ssh -G` without connecting), clone, fetch, explicit-origin fast-forward-only pull; preview and confirm for staging a named file, committing staged material and non-force pushing the current branch. No keys, SSH config or Git remotes are rewritten.
- `Computer learn` is a two-step command-shape review and confirmation to enable *only* named aliases for existing read-only intentions. Arbitrary shell, new executors and write operations are refused.
- `Computer --json search scopes` and `Computer --json find dependency rexx crypto in dependencies` return structured machine-readable evidence.
- Full contract, platform examples and Codex instructions: `docs/GITHUB_SCOPES_AND_LEARNING.md` and `AGENTS.md`.

## Claude's contribution integrated (dev2)

The 2026-10-13 Claude Sonnet 5.5 first cut contributed these useful intentions:

- `Computer check free space [on ed209b]` — runs local `df -h` or invokes the authoritative `sshnode.sh --job-id JOB NODE df -h` argv contract.
- `Computer check free memory [on ed209b]` — runs local `free -h` or invokes `sshnode.sh --job-id JOB NODE free -h`.
- `Computer deploy zipfile NAME.zip to ed209b` — staged ZIP transfer. The first invocation only prints a preview, returning exit 3. It creates a cryptographically random, 32-character confirmation token with 10-minute expiry. Only `Computer confirm TOKEN` consumes the token and performs the authorized `sshnode.sh --job-id JOB --transfer NODE FILE` action; it checks the ZIP's SHA-256 bytes and authority-script SHA-256 before execution.
- `Computer run tests` — runs local package qualification. Installed package includes tests and tool scripts.

The confirmation is bound to the user-owned private state directory (0700) with mode-0600 token files. It is single-use even when execution fails. Ambiguous ZIP filenames are rejected, and sources must be within configured file-search roots. The transfer is a file copy **only**, not execution of an uploaded archive. Use `COMPUTER_DRY_RUN=1` to observe the exact argv without connecting. The user-supplied SSH and cloud scripts remain unchanged.

The Python executor handles subprocess arguments as argv arrays rather than interpolating natural language into a shell. The ooRexx Intention Service still performs the semantic READY gate and per-invocation discovery. The registered local grammar is deliberately bounded; this is **not** yet a general pluggable specialist intention directory.

## Commands

```text
Computer add ~/Downloads to my find file locations
Computer add ~/Downloads/current to my find file locations
Computer add ~/Downloads/current to my find file locations as inboundfiles
Computer add ~/dependencies to my find file locations as dependencies
Computer search scopes
Computer --json find new files in last 30 minutes in inboundfiles
Computer --json find dependency rexx crypto in dependencies
Computer github help
Computer github inspect /absolute/repository
Computer github fetch /absolute/repository
Computer github pull /absolute/repository
Computer github stage /absolute/repository file src/Crypto.cls
Computer github commit /absolute/repository message "Review Crypto"
Computer github push /absolute/repository
Computer learn help
Computer learn locatecrypto as "find dependency rexx crypto in dependencies"
Computer add /tmp to my permitted temporary file directory
Computer find files received in my find files location in the past 30 minutes
Computer which file has 'the description of interest'
Computer find the latest copy of Crypto rexx class
Computer set up the rexxpath
Computer check free space
Computer check free memory on ED209B
Computer deploy zipfile example.zip to ED209B
Computer confirm <token>
Computer run tests
Computer log me into ED209B
Computer fix the firewall on ed209f
Computer discover
Computer config
Computer rexxpath
```

`add` writes persisted configuration atomically; duplicates are ignored. Existing searchable directories are required. The temporary directory allowlist is persisted as a **policy declaration** for future temporary-file operations; this first release does not create user temporary files there.

`find files received` uses Linux inode change time as an explicitly labeled **proxy** when creation/birth time is unavailable. It does not claim authoritative download timestamps. Scans do not follow symlinks, are bounded to 50,000 files/16 levels and list at most 40 results. `which file has` searches UTF-8-ish text including bounded unencrypted ZIP members; large/binary files are omitted. `latest copy ... class` orders candidates by filename semantic version and mtime; **candidate selection is not release authenticity verification**.

`set up the rexxpath` writes `rexxpath.sh`, which the operator must **source** from the parent shell. It scans existing `.cls` files under authorized search roots, preserving any existing `REXX_PATH`. It never changes `.bashrc` or pretends a child process can export to a caller.

`log me into ED209B` calls the **unchanged `sshnode.sh` implementation**, inheriting its configured OpenSSH, identity, SSH config, user mapping and logs. The original attached `sshnode.sh` and `cloudctl.sh` are packaged, unchanged, as adapter snapshots; export `COMPUTER_SSHNODE=/actual/sshnode.sh` and `COMPUTER_CLOUDCTL=/actual/cloudctl.sh` to use the *current installed authority*. No newly invented SSH key-pin gate is added. `COMPUTER_DRY_RUN=1` prevents the SSH connection while showing the intended adapter and target.

`fix the firewall on ed209f` is presently **blocked** because the attached `sshnode.sh` has **no ed209f mapping** and the attached `cloudctl.sh` requires provider-scoped resources and parameters. For known SSH targets, the command supplies an explicit plan-only diagnostic (returns 4); it does not blindly open ports, change XTP underlay topology or assume cloud credentials. A later implementation needs a verified ED209 node-to-provider resource registry, current peer policies, read-only inspection, an action plan and a separate authorized commit.

## Install

Requires `rexx` (ooRexx 5.3.0 r13196 tested) and `python3` (standard library only). ooRexx was validated using the **uploaded Debian build extracted in isolation**, with no system installation. No live SSH or cloud operation was run.

```bash
unzip scotty_computer_v0.1-dev5.zip
cd scotty_computer_v0.1-dev5
bash tools/qualify.sh
bash tools/install.sh
export PATH="$HOME/.local/bin:$PATH"
Computer help
# Use the system's installed current helpers, rather than relying on the snapshots:
export COMPUTER_SSHNODE="$HOME/path/to/sshnode.sh"
export COMPUTER_CLOUDCTL="$HOME/path/to/cloudctl.sh"
```

Linux `unzip` preserves executable flags. If another extractor drops them, run the test and installer using `bash tools/qualify.sh` and `bash tools/install.sh` as above, and run the native program using `rexx ./Computer`.

The installer is deliberately **non-overwriting**: it refuses to replace an existing `Computer` command or installed tree. Choose `COMPUTER_BIN_DIR` and `COMPUTER_INSTALL_ROOT` for a parallel installation before promoting it. For a non-default ooRexx binary, set `REXX_BIN` for the launcher and qualification. For local standalone direct invocation: `rexx /path/to/package/Computer 'find ...'`. Do not execute the tools installer as root unless that is deliberately intended.

## Qualification

```bash
REXX_BIN=/usr/local/bin/rexx ./tools/qualify.sh
```

- 54 Python unit regressions (state, dedup, 0600 audit, ZIP member, semantic version order, safe search, REXX_PATH, SSH dry-run, unknown-node rejection).
- Native ooRexx end-to-end integration through actual IntentionService dev11 (`discover`, roots, temp allowlist, recent files, content, latest class, REXX_PATH, ED209B dry-run, ED209F block, missing-adapter rediscovery, remote check and confirmed ZIP transfer through traceable stub).
- Third native ooRexx integration suite: governed local/remote jobs, revocation and no-extraction document reading.
- Bash syntax checks for the user-supplied SSH/cloud adapters.
- No successful cloud repairs or live machine connections are claimed. Claude's **original** separate suite passed 39/39 in isolation but was not used as the security acceptance suite; its first-cut files are retained in `docs/claude_reference/`. See `docs/CLAUDE_MERGE_REVIEW.md`.

## Exit statuses

`0` success; `1` no result/not-found file; `2` unknown intention or malformed input; `3` needs details, confirmation pending, or cannot configure; `4` authority/scope blocked, expired or spent token; `5` other local execution error.

## Dependency and authority boundary

`vendor/` is a **byte-for-byte copy** of the published Intention Service v0.1-dev11 `src/` files from the user's Library package `oorexx_intention_service_v0.1-dev11.zip`; sources are kept with their upstream copyright headers. Do not modify the vendored core to introduce Computer-specific semantics. See `docs/PROVENANCE.md` for the original packages and qualification boundary.


## Dev8: honest output-exception evidence

An output burst that temporarily exceeds a single sampling read no longer incorrectly makes the entire run incomplete. Once the child exits, Computer drains outstanding output within a 64 MiB per-rule/per-stream bound and searches across chunk boundaries; a genuinely exceeded bound or unreadable receipt is recorded as `measurement_unavailable`. See `docs/DEV8_CHANGES.md`.
