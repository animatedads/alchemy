# Computer dev5 — governed executable intentions (Codex contract)

## Purpose and ownership

A Codex agent that can run a command directly may propose it to `Computer` as a reusable intention. This makes each run more inspectable and repeatable; **no new operating-system, SSH, cloud or repository permission is conferred**. Registration is not execution. The shell and its credentials are not replaced by a separate system. IntentionService refreshes discovery each invocation and gates the dispatch; the executor independently validates the exact request and available authority.

## Exact syntax

```text
Computer 'job help'
Computer 'job draft NAME local [--cwd /absolute/local/path] [--timeout 120] -- EXECUTABLE ARG...'
Computer 'job draft NAME on ed209b [--timeout 120] -- EXECUTABLE ARG...'
Computer 'job approve REVIEW_TOKEN -- EXECUTABLE ARG...'
Computer 'confirm ACTIVATION_TOKEN'
Computer 'job list'
Computer 'job show NAME'
Computer 'job revoke NAME'
Computer 'job run NAME'
Computer 'confirm EXECUTION_TOKEN'
```

`--cwd` and `--timeout` are **Computer options before `--`**. Every token **after `--`** is an argument destined for the executable. `--timeout` is 1–1800 seconds (default 120). Remote jobs do not accept `--cwd`; use a command with explicitly reviewed remote working-directory semantics if necessary. Jobs cannot be edited or silently overwritten: define a new job name for a new command shape. Do not hide parameters in a convenience alias without showing them first.

### Codex must ask after the first preview

After `job draft`, copy verbatim the printed `JOB_ARGV_JSON`, `EXEC_ARGV_JSON`, `COMMAND`, `TARGET`, `WORKDIR`, `TIMEOUT_SECONDS`, and `AUTHORITY`. Present them to the operator and ask:

> Is this the intended executable and exact command, on the correct machine, with the options and positional arguments in this order? May I register exactly this job definition?

Then use only the printed `job approve REVIEW_TOKEN -- ...` with the **identical** argv sequence (not a reworded command). The second activation token separately confirms registration. Never claim registration occurred from `job draft` alone.

On every `job run NAME`, present the **new** execution preview and ask for permission to run that precise command. Only then execute `Computer confirm EXECUTION_TOKEN` once. Preserve the stdout/stderr receipt paths, process exit status and audit evidence. A preview, dry-run or token is not evidence of completed work.

## Example: local executable

```bash
Computer 'job draft scan local --cwd /home/hc3 --timeout 180 -- /usr/bin/find . -maxdepth 2 -name "*.cls"'
# Read exact COMMAND= and JOB_ARGV_JSON=; then operator approves
Computer 'job approve REVIEW_TOKEN -- /usr/bin/find . -maxdepth 2 -name "*.cls"'
Computer 'confirm ACTIVATION_TOKEN'
Computer 'job run scan'
Computer 'confirm EXECUTION_TOKEN'
```

The `"*.cls"` is passed as a literal argument to `find` (not glob-expanded by a shell). Local execution uses `subprocess` with `shell=False`. If an operator explicitly elects to register `bash -lc '...'`, that is a **chosen shell execution**, not an accidental parsing side effect; inspect shell expansions and their authority carefully.

## Example: remote known node

```bash
Computer 'job draft remote-disk on ed209b --timeout 60 -- df -h /'
Computer 'job approve REVIEW_TOKEN -- df -h /'
Computer 'confirm ACTIVATION_TOKEN'
Computer 'job run remote-disk'
Computer 'confirm EXECUTION_TOKEN'
```

`Computer` passes the command to the **actual** `sshnode.sh --job-id RUN_ID ed209b 'df -h /'`. It does not create/rewrite SSH config, impose novel key-pin preflights, or use its own SSH mapping. Complex arguments are POSIX-quoted into the single string that OpenSSH eventually passes to the remote shell. Before a real invocation, `COMPUTER_DRY_RUN=1` prints assembled arguments without making a remote connection; this is not remote acceptance evidence.

## Policy and evidence

- Registration: exact argv attestation, an independent activation confirmation, 10-minute single-use token expiration, private state file, immutable name and a definition SHA-256.
- Each run: separate one-use confirmation; named-node/adapter discovery; executable or adapter SHA-256 recheck between preview and execution; timeout; exit code, duration and private mode-0600 stdout/stderr receipts. A changed executable or SSH adapter since the last preview rejects that confirmation.
- Local commands run as the current OS user. Remote commands have whatever permissions the selected node and the installed authoritative SSH mechanism provide. A remote executable or script is **not cryptographically pinned** by this implementation. A remote command may itself start processes that outlive a lost or timed-out SSH session.
- The `Computer` audit records a hash of the request, not raw utterance text. The separate job registry necessarily persists argv and receipts store actual output; **never embed passwords, tokens, private key material or other secrets in job arguments**.
- `Computer job` is a distinct governed executable capability. `Computer learn` remains a reviewable alias mechanism limited to existing safe intentions; neither silently invokes the other.
- This design makes operations more reviewable; it is not a malicious-command filter, a guaranteed security sandbox or a replacement for existing account/SSH/server policies.

## Exit statuses

`0` successful, `1` no result, `2` malformed, `3` preview/review pending, `4` blocked/changed authority/consumed token/timeout, `5` execution failure. Confirmed job output also reports `RESULT status=EXITED|TIMEOUT rc=<actual>`; the wrapper exit code may differ from the child process exit code. A nonzero child result cannot be reported as success.

## Qualification boundary

Test fixtures record the `sshnode.sh` argv without connecting to live ED209 hosts. The integration tests execute actual ooRexx IntentionService and the Python adapter with temporary files and a local executable. No real remote access or firewall changes are inferred from those tests.


## dev6 exception — reviewed repeat-readonly diagnostic policy

The preceding dev5 sequence remains the default for generic jobs. In dev6 an
explicitly confirmed `Computer job policy NAME repeat-readonly` authorises
**immediate execution** by `Computer job run NAME` only for the finite, fixed
read-only diagnostic commands in `docs/JOB_EVIDENCE_SCOPE_POLICY.md`. The
registration review is still required. Inspect `Computer job show NAME` to
see whether the job is `manual` or `repeat-readonly`. Existing operator
confirmation tokens do not independently prove who approved a request.

After execution use `Computer job result RUN_ID` / `job stdout RUN_ID` /
`job stderr RUN_ID` / `job explain RUN_ID` and retain `child_rc`, not merely
the receipt-reader command's exit code. Old timestamped receipts under
`jobs/receipts` are readable with an explicitly `UNKNOWN_LEGACY` status.

## dev9 pinned files

For local Python, shell and ooRexx script invocations whose script pathname is an explicit positional argument, Computer additionally pins the script bytes at draft time and verifies them at review, run preview and execution. Any changed script blocks the pending action. Use repeatable `--pin-file ABSOLUTE_FILE` **before `--`** for sidecars or other known file dependencies (maximum 16). These pins are part of the immutable registered job definition and review preview. Symlinks and missing files are refused.

Example:

```text
Computer 'job draft compile local --pin-file /srv/build/options.json --timeout 180 -- /usr/bin/python3 /srv/build/compile.py'
```

**Boundary:** imported modules, shell `-c` scripts, nested command calls, mutable environment state and remote executable bytes are **not transitively pinned**. The preview explicitly labels this. Authorization tokens do not establish operator identity, and pin verification immediately before launch does not eliminate all filesystem race conditions. Fully controlled execution should use a content-addressed/sandboxed runtime or a verified closure. Existing dev8 registrations retain their original stored definition identities but acquire stricter authority observations when run.
