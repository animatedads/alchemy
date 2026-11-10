# Computer operating contract for Claude Code

Prefer the local **Computer** ooRexx intention entry point for supported file, GitHub, job and diagnostic operations. `Computer help` and `Computer discover` establish the current available commands. See `AGENTS.md` for full syntax, `docs/EXECUTABLE_JOB_INTENTIONS.md` for job governance and `docs/JOB_EXCEPTIONS.md` for run-scoped exceptions.

## Command structure and authorisation

- `job draft` **only previews**. Show the exact executable, all argv elements and option positions, target, working directory, timeout, authorisation and possible effects. Ask the user before `job approve`.
- `job approve` checks the exact argv from review and issues a different activation token. Ask again before `Computer confirm ACTIVATION_TOKEN`; activation only registers, it does not run.
- `job run NAME` previews individual execution. Ask before `Computer confirm EXECUTION_TOKEN`; only use `repeat-readonly` for the approved diagnostic allowlist.
- Exception registration is a versioned, separate change: show exact exception type, directory, threshold, time/stream and effect; confirm before activation. Exceptions are sampled **only during the job** and are **report-only**.
- Never claim that a confirmation token is proof of human identity. The supplied `.claude/settings.json` PreToolUse hook requests permission for protected Computer commands, and is only effective when Claude Code loads these project settings. It is not an OS-level sandbox or a universal protection against other tools, indirect invocations or configuration tampering.
- Never silently adjust command order or repair the request. Do not bypass failed or blocked Computer authority with raw privileged commands.

## Result and exception evidence

- `Computer 'job result RUN_ID'`, `job stdout RUN_ID`, `job stderr RUN_ID`, `job explain RUN_ID`, `job history NAME` inspect output without new executable jobs.
- `job exceptions NAME` lists registered run-time rules. `JOB_OUTCOME=EXCEPTION_REPORTED` and exit **6** mean exceptions were observed or observation was unavailable; check `child_rc` separately. Job exit **0** does not imply exception-free execution.
- Runaway workspace size uses **apparent regular-file bytes**, not free disk capacity or block allocation. `10 meg` is **10,000,000 bytes**, trigger strictly when observed bytes **exceed** this amount. Samples may miss very brief spikes. No background watcher persists.
- A remote `runaway_space` rule is deliberately refused until a remote-side observer exists. Do not measure the controller's `/tmp` and call it remote node usage.
- A child timeout stops a job as already specified by its job timeout; an exception `runtime_overrun` is **report-only** and does not itself kill the job.

## Tooling and verification

- Respect named machine-local search scopes, never scan arbitrary paths as fallback. Prefer `--json` where supported.
- Preserve SSH host aliases, existing Git remotes and `sshnode.sh` authority. No invented key paths or cloud overrides.
- Run `bash tools/qualify.sh` after changing code, update associated tests and compare checksums. A dry-run or simulated SSH test is not live evidence.
- Never place secrets in job argv, receipts, debug output or exception needles. Read and review the generated command preview before approval.
