# Typed execution and WLU-aware scheduling

QueueRexx v0.1-dev8 activates payload execution as an internal/API surface while keeping the public mutating CLI disabled.

## Authority boundary

`QueueExecutionService` owns execution lifecycle coordination; runner providers own mechanisms only.

```text
QueueExecutionService
  QID lock
  execution journal
  runtime metadata
  terminal/cancel transition
       |
       +-- DirectRunnerProvider  -> POSIX process group / PID evidence
       +-- SystemdRunnerProvider -> transient user unit / MainPID evidence
```

A runner provider never renames a QueueBash job file and never settles WLU.

## Recovery-safe launch

Start requires exactly one authoritative `running` record. QueueRexx writes a PREPARED execution intent before calling the provider. A successful provider launch creates durable mechanism-specific evidence:

- direct: PID/PGID locator plus exit-code locator;
- systemd: deterministic `SYSTEMD_UNIT` plus exit-code locator.

QueueRexx then atomically replaces the job record with appended QueueBash-compatible runtime fields (`RUNNER_USED`, `RUN_PID`, `RUN_PGID`, `SYSTEMD_UNIT`, `RUN_STARTED_AT`, QueueRexx execution locators). Existing and unknown record fields are preserved.

If QueueRexx dies after provider launch but before metadata replacement, reconciliation reads PREPARED intent and the durable provider locator and reconstructs metadata. It never relaunches merely because metadata is absent.

## Direct process launcher

Direct work is started in a separate process group. The background launcher intentionally does not use ooRexx `ADDRESS SYSTEM ... WITH OUTPUT/ERROR`: keeping capture pipes attached to a background process can stall/interfere with the initiating Rexx command. A dedicated non-capturing executor launches the background process; PID/PGID identity is returned through an atomically replaced locator file.

Payload stdin is `/dev/null`; stdout/stderr append to the QueueBash-compatible job log. The wrapper atomically records the payload exit code before exiting.

Linux observation treats a zombie-only PID or process group as dead execution evidence rather than LIVE merely because `kill -0` would still find the PID.

## Terminal reconciliation

A durable exit locator is authoritative execution evidence:

```text
exit 0      -> running -> done
exit nonzero -> running -> failed
```

For WLU-managed jobs the terminal decision is passed to `QueueWLUTerminalService`, preserving the existing queue/WLU two-authority recovery contract.

A provider reporting DEAD without a durable exit code is ambiguous and does not cause QueueRexx to guess done/failed.

## Cancellation

For a running record QueueRexx first requests provider termination. Successful `kill` or `systemctl stop` invocation is not enough. QueueRexx immediately asks the same provider for observation evidence and commits `cancelled` only when that result is conclusively `DEAD`.

`LIVE`, `UNKNOWN`, or `LAUNCH_PENDING` after terminate leaves the shared record unchanged. This prevents an acknowledged-but-still-running payload from being hidden behind a terminal queue state.

A real QueueBash 0.18.144 cancellation of a QueueRexx-started direct process is also qualified. QueueBash's terminal filesystem decision remains authoritative; later QueueRexx reconcile reports terminal and does not rewrite it.

## WLU-aware scheduling

WLU is an eligibility/capacity authority, not priority currency.

`QueueJobScheduler` asks its admission provider whether each candidate may execute. `QueueWLUSchedulingAdmission` requires the durable ACTIVE WLU reservation and a matching `reservationRef`, then delegates current placement acceptance to Job-to-Node v0.6 `verifyLease()` using the exact retained placement request. A matching token alone is not eligibility evidence. Unmanaged pending jobs use ordinary admission.

Among eligible jobs, normal QueueBash priority wins; lexical record path is the deterministic tie-breaker.

`QueueTypedWorker` then composes:

1. scheduler decision;
2. execution policy;
3. WLU activation + placement for managed work, or ordinary claim for unmanaged work;
4. `QueueExecutionService~start()`.

No layer bypasses QID locking, WLU Authority, Job-to-Node placement or runner-provider selection.

## Systemd qualification

Dev8 provides real systemd-run backend mechanics but does not claim a live systemd-user-host qualification in this package. Deterministic tests inject Linux/systemd platform facts and a fake backend/probe to prove selection, deterministic unit metadata, authoritative MainPID observation, termination delegation and fail-closed cancellation when stop cannot be confirmed.
