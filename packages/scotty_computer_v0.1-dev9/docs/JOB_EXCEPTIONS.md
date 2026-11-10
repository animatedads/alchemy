# Computer dev7 — job-scoped expected exceptions

**Not a monitoring subsystem.** Registered rules are part of a job's execution contract. The foreground Computer invocation samples/checks conditions while it waits for that job and records observations in its immutable per-run receipt. No independent service, daemon, periodic task, or notification is created.

## Example: workspace 10 meg limit

```sh
Computer 'job draft build local --timeout 120 -- /usr/bin/make all'
# Review exact argv and confirm the two-stage registration.
Computer 'job exception register build runaway_space /tmp/myworkspace 10 meg'
# Review the workspace, unit and threshold, then confirm the exception definition.
Computer 'job exception register build runtime_overrun 60 seconds'
Computer 'job exception register build output_contains "ERROR:" both'
Computer 'job exceptions build'
Computer 'job run build'
# Review exact command and confirm this particular execution.
Computer 'job result RUN_ID'
Computer 'job explain RUN_ID'
```

The space limit is **absolute apparent file size** in a named directory, recursively summed for regular files without following symlinks. `10 meg` means 10,000,000 bytes; `10 MiB` means 10,485,760 bytes. The rule raises only when the sampled current size is **greater than** the limit: 11,000,000 bytes is an exception, exactly 10,000,000 is not. It is not a free-disk-space rule, allocated-block rule or percentage-growth estimate.

`runtime_overrun N seconds` checks job elapsed wall time strictly above N. Unlike the job's own hard `--timeout`, it **reports without terminating**. `output_contains "ERROR:" [stdout|stderr|both]` checks exact case-sensitive bytes emitted by the child and flags the first occurrence; merely exiting nonzero is not the same observation. Exiting zero does not suppress an observed exception.

Registration returns preview and a separate one-use confirmation token. The rule set is snapshotted and SHA-256-bound to the pending job execution. Changing rules makes a previously-previewed run invalid; re-preview to execute. Registration never starts a job. The run's results contain `exceptions` with the registered definitions, raised events, observation status and sampling details. Exit code 6 means **exception observed or observation incomplete**; `child_rc` remains an independent field. The runner retains stdout and stderr.

### Measurement limits

A 100-ms sampling interval is currently used for workspace and elapsed-time observations; a very short size spike may be missed. Every final output file is scanned again at completion for the bounded `output_contains` condition. A flood of output can exceed the per-tick budget and mark the observation incomplete. Workspace walks are bounded in entry count and depth; unavailable paths or exceeded budgets are **reported**, never interpreted as a clean run. Rule-triggering does **not** kill the child or modify filesystem permissions. Remote workspace checks are blocked until an explicitly deployed remote observer and authoritative remote measurement evidence are available.

### Responsibility and approval

The owner of the job may register exception conditions, but the operator should review their scopes before confirming. A project-local Claude Code PreToolUse hook is supplied to request interaction at approval points; use a real external authorisation provider if independently verifiable human identity is required. This is not provided by bearer tokens alone.

## Dev8 — output observation completeness

The observer scans at most 1 MiB per live sampling tick for each output rule and stream. A pending backlog while a job is still producing output is **not** considered lost evidence. Once the child has finished, the foreground observer drains the remaining stdout/stderr bytes within the explicit 64 MiB per-rule/per-stream ceiling. Only an unreadable stream or a genuinely exceeded final budget yields an incomplete observation with a `measurement_unavailable` event. Matches spanning reads are detected. A completed clean run reports the number of bytes examined and the scan ceiling in its exception receipt. This does not change the 100-ms workspace-size sampling limitation or the report-only policy.
