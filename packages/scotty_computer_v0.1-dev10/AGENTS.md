# Codex/automation operating contract — Computer v0.1-dev10

**Computer is the preferred command front-end for the supported intentions.** Use it, inspect the exit status, and retain the printed evidence. Do not replace a failed or blocked `Computer` action with an invented privileged workaround or altered authority scripts. If a task needs a real command not yet supported, use the governed `Computer job draft` / `job run` interface below, not an unreviewed substitute.

## Invocation

- Use `Computer help` to see current commands and `Computer discover` to see available adapters on this invocation.
- For an accurate path or filename containing spaces, quote it **inside the Computer utterance**, for example: `Computer 'sha256 "/home/me/Downloads/file one.zip"'`.
- In scripts, call `Computer '--json sha256 "/absolute/path"'`. JSON is supported for integrity instructions, named search results, and search-scope listing; it is not a universal flag for every command. Capture stdout as one JSON record; stderr may contain startup diagnostics.
- If a basename resolves to multiple registered files, give an explicit absolute filename. Never select a candidate silently.
- Quote the entire utterance when invoking from the shell, or pass its words as normal arguments; no remote shell code is accepted by integrity instructions.
- If a requested operation is unsupported, report it as unsupported; `Computer` is not a general-purpose shell interpreter.

## Integrity instructions

```text
Computer sha256 /absolute/file.zip
Computer sha512 /absolute/file.zip
Computer sha1 /absolute/legacy.bin
Computer compare sha256 /absolute/a.zip with /absolute/b.zip
Computer compare files /absolute/a.zip with /absolute/b.zip
Computer verify sha256 <64-hex-sha256> /absolute/file.zip
Computer verify manifest /absolute/SHA256SUMS
Computer find sha256 <64-hex-sha256>
Computer inspect /absolute/file.zip
Computer list zip /absolute/file.zip
Computer test zip /absolute/file.zip
Computer --json sha256 /absolute/file.zip
Computer --json compare files /absolute/a.zip with /absolute/b.zip
```

- `sha256`, `sha512` and `sha1` stream a local file's **bytes** and report the algorithm and byte count. SHA1 is for identifying legacy artifacts; do **not** use it to establish security authenticity.
- `compare sha256` reports SHA256 equality, not formally byte comparison. `compare files` additionally streams and compares the bytes; prefer it for identical-copy claims.
- `verify sha256` checks a supplied expected digest. A checksum alone does **not** establish the publisher's identity or the authenticity of the expected checksum.
- `verify manifest` reads a local GNU sha256sum-style manifest. Entries must be relative to its containing directory, with no parent traversal or symlink jumps; missing/changed files fail. GNU escaped filenames are not accepted; there is no signing/trust inference.
- `find sha256` searches *registered file search roots* only; it is bounded to 50,000 entries / depth 16 / 2 GiB hashed, and refuses to claim `NOT_FOUND` if the byte budget is hit. If results hit the limit, output includes `complete=false`.
- `list zip` lists names/sizes, no extraction; `test zip` reads compressed members to test ZIP CRCs, bounded to 256 MiB uncompressed. Unsafe, encrypted and over-limit ZIP contents are refused. Passing CRC is not an authenticity signature.
- Direct absolute paths can be read outside registered roots, but never modified. Basenames resolve inside registered search roots and must be unique. Explicit file symlinks are refused.

## Exit codes — do not ignore

| Exit | Contract |
|---|---|
| 0 | Operation succeeded; for compare/verify, the expected equality was established |
| 1 | `MISMATCH` or `NOT_FOUND`, never silently successful |
| 2 | Unsupported or malformed command |
| 3 | Ambiguity, missing information, or scan budget prevents a complete answer |
| 4 | Refused for policy/unsafe input, or missing authority |
| 5 | Runtime I/O error or concurrent mutation detected |

For structured integrity responses: require `schema=scotty.computer.integrity/1`, inspect `status`, `rc`, `operation`, paths, and algorithm. A zero process status **and** response `rc:0` must agree. Do not interpret `ERROR`, `MISMATCH`, `NOT_FOUND`, or incomplete results as success.

## Other Computer instructions

- `Computer add ~/Downloads to my find file locations` persists a search root.
- `Computer find files received in my find files location in the past 30 minutes` uses filesystem timestamps, **not** verified receipt provenance.
- `Computer find the latest copy of Crypto rexx class` ranks candidates; **not** an official-release proof. Hash the selected copy, then compare with a trusted expected digest.
- `Computer check free space on ed209b` and `Computer check free memory on ed209b` use the unchanged authoritative `sshnode.sh`; no custom SSH bypass, key preflight or synthetic host aliases.
- `Computer deploy zipfile artifact.zip to ed209b` previews only. Run `Computer confirm TOKEN` only with genuine operator authority; it is single-use and rechecks source/SSH adapter bytes.
- `Computer fix the firewall on ed209f` is **not implemented**: no firewall change is made. Never substitute broad firewall opening or cloud resource guessing.
- Use `Computer run tests` after updating the package. Changes to command coverage require new end-to-end and negative tests.

**Evidence**: Use a full path, SHA-256, file size, source location, operation status, and test result when handing artifacts to another actor. Keep audit records content-blind; do not log secrets, private file contents or authentication material.

## Named-scoped searches — mandatory when a scope is specified

- `Computer 'add /home/hc3/Downloads to my find file locations as inboundfiles'` is a **local configuration** example only. On other machines, `inboundfiles` might be `/mnt` or `/home/bacon`. Never use another machine's absolute path or assume it exists.
- `Computer 'search scopes'` to see the machine-local registry; `Computer '--json find new files in last 30 minutes in inboundfiles'` to search only `inboundfiles`.
- `Computer '--json find dependency rexx crypto in dependencies'` identifies candidates by name, including bounded archive member names, **without extraction**. Inspect `count`, `truncated`, `modified_utc`, `size_bytes`, `reason`, `sha256`, `hash_status`. Sorted by descending modification time; never silently substitute a guess at “latest release.”
- If a search scope is unknown, report it and request registration instead of scanning `/`, HOME, Downloads, or every mount. A ZIP archive checksum is **not** a ZIP member's checksum.

## GitHub intentions — project SSH key authority

- `Computer 'github inspect /absolute/repo'` prints the origin URL, SSH Host alias, effective `ssh -G` profile, any Git SSH override, and branch. Do not print private key contents or inject a new `IdentityFile`; Git and `~/.ssh/config` own that decision.
- Read operations: `github clone GITHUB_URL to ABSOLUTE_DEST`, `github fetch REPO`, `github pull REPO`. Pull uses `--ff-only origin <current-branch>`. An unavailable host, dirty tree or unapproved remote must **not** be worked around by changing identity or remote.
- Write operations: `github stage REPO file RELATIVE_FILE`, `github commit REPO message "MSG"`, `github push REPO`. These yield preview and exit 3, **not execution**. Present the exact `ARGV`, `COMMAND`, branch, SSH alias and file/hash details for operator approval; then `Computer confirm TOKEN` exactly once. Check the result, not just the preview.
- `COMPUTER_DRY_RUN=1` prints actions without making the associated Git/SSH network or file change. Dry-run is not deployment proof. Git commit hooks may execute code. NEVER `git push --force` implicitly.

## Governed learning — Codex must ask, not assume

- Start: `Computer 'learn NAME as "existing read-only Computer intention"'`.
- Report the exact printed **COMMAND=** and **POSITIONAL/OPTIONS=**, asking the operator to verify option placement, positional arguments and the intended effect. Do **not** silently correct a malformed command.
- The tool gives a first `learn review` token. Submit the **exact** rendered command with that token (no rearranging options); only then will it issue a separate `Computer confirm TOKEN` to activate. These are time-limited and single-use.
- `Computer 'do NAME'` always reclassifies the approved command against the read-only alias allowlist. For an actual executable command, including Git, administrative, and remote commands that the invoking user is otherwise permitted to run, use the distinct governed `Computer job draft` workflow below; `learn` never silently becomes `job`.
- Details: `docs/GITHUB_SCOPES_AND_LEARNING.md`. Unsupported requests require a new specialist implementation and qualification, not a bypass.


## Executable job intentions — do not execute without review

**Use `Computer job help` and `docs/EXECUTABLE_JOB_INTENTIONS.md`**. Codex is allowed to propose arbitrary executables and exact arguments, including commands on known remote servers, but only with the credentials/permissions of its current OS user. New jobs are immutable and do not execute during registration. All jobs default to per-execution confirmation. A separately confirmed **repeat-readonly** policy permits direct repeated execution of a finite set of diagnostic argv vectors only; check `job show NAME` before invoking `job run` because it will execute immediately under that policy.

```text
Computer 'job draft diskcheck on ed209b --timeout 120 -- df -h'
Computer 'job approve REVIEW_TOKEN -- df -h'
Computer 'confirm ACTIVATION_TOKEN'
Computer 'job show diskcheck'
Computer 'job run diskcheck'
Computer 'confirm EXECUTION_TOKEN'
```

After draft, **Codex must ask the operator to confirm the exact command structure**. Display the full `JOB_ARGV_JSON`, `EXEC_ARGV_JSON`, `COMMAND`, `TARGET`, `WORKDIR`, `TIMEOUT_SECONDS`, and pinned `AUTHORITY`. Ask explicitly: *Is this the correct executable, target, argument/option order, and effect? Shall I register precisely this command?* Never reorder options or substitute a different shell, SSH identity, executable, node, or path. The `job approve TOKEN -- ...` must contain precisely the same argument sequence. A new token is issued for activation. Per-run confirmation is the default; separately approved `repeat-readonly` diagnostic jobs execute immediately upon `job run` as documented below.

For remote commands the **only transport** is the configured `COMPUTER_SSHNODE` (or packaged authority snapshot), and its known-node map is validated. OpenSSH invokes a remote shell; individual argument values are POSIX-quoted into one remote command string, not blindly concatenated. `COMPUTER_DRY_RUN=1` only proves the assembled command shape; it does not prove connection or remote execution. `sshnode.sh` and `.ssh/config` control credentials and access. Output receipts live in the private user configuration directory and may contain command output/secrets: do not pass secrets via argv or paste credentials into learned job definitions. Jobs are not privilege sandboxes, remote binary pins, or a means of bypassing server permissions.


## Dev6 — mandatory receipt and repeat-authority rules

- **Never register a `cp` or shell job merely to inspect another job's output.** Use `Computer job result RUN_ID`, `job stderr RUN_ID`, `job stdout RUN_ID`, or `job explain RUN_ID`. Use `job history NAME` to locate indexed runs. Read-only retrieval has no confirmation. Inspect `child_rc` as well as receipt status; retrieval `rc=0` is NOT child success.
- Pre-dev6 receipts may have no indexed JSON record. Such results are `UNKNOWN_LEGACY` and may **not** be presented as successful executions.
- Use `Computer 'find directories matching xtp in xtpwork'` to narrow a named search scope before any file/dependency scan. Directory search never crosses into another scope. `complete=false`/rc=3 means it did not establish absence.
- `Computer job policy NAME repeat-readonly` is a **policy-change preview**, not automatic authority. Show exact pinned argv, machine/SSH target, resolved executable, SSH configuration hash and effect. Require real operator confirmation of the policy token.
- **After the repeat policy is confirmed**, `Computer job run NAME` performs execution immediately. It is NOT a preview. Only the finite exact diagnostic list in `docs/JOB_EVIDENCE_SCOPE_POLICY.md` qualifies. Arbitrary commands, shells, sudo, network writes, Git writes, deployments, firewall changes do not.
- `Computer job policy NAME manual` restores per-run confirmation after its own separate approval. Confirmed job revocation also removes its repeat policy.
- No human-identity proof is enforced by the tokens. Codex must genuinely ask; do not manufacture an approval from its own command output.
- Changes to the pinned local binary or sshnode.sh/SSH-config hash stop reusable execution. A remote binary or SSH agent cannot be independently pinned by this release, and an SSH exit zero alone is not XTP success.

## Dev7: registered, job-scoped exceptions

Use `Computer 'job exception register NAME runaway_space /absolute/workspace 10 meg'` to register a 10,000,000-byte *apparent file-size* ceiling. The exception applies if any sampled size **exceeds** the ceiling while that job is executing. Related rules: `runtime_overrun N seconds` (report-only; separate from the hard job timeout) and `output_contains "ERROR:" stdout|stderr|both` (exact case-sensitive bytes). Present the rule preview and get approval before confirming its token. Use `Computer 'job exceptions NAME'` to inspect. `job start NAME` is a synonym for `job run NAME`. Output has child_rc **and** exception observations separately; exit 6 means exception raised or observation incomplete, even if the child succeeded. The runner only samples while its own child is active and does not spawn a monitoring daemon. Sampling may miss a very short spike. Remote directory size observation is not implemented; do not label local samples as a remote measurement.

Claude Code reads `CLAUDE.md` and can opt into the bundled `.claude/settings.json` PreToolUse hook to request operator interaction for approvals/confirmations. This is not proof of human identity or defence against an independently privileged process. See `docs/JOB_EXCEPTIONS.md`.

## Dev10 process lifetime

Jobs execute in a fresh POSIX session. On a job timeout the local process
group is sent SIGKILL (where supported); the run record reports the actual
termination attempt. Registered exceptions remain report-only. Do not claim
that remote processes or explicitly detached descendants were terminated.
Inspect `TERMINATION_ATTEMPT=` and the run receipt for timeout evidence.
