# QueueRexx provider-aware runtime monitoring and recovery

QueueRexx dev9 separates **runtime observation** from **runtime mutation**.

The QueueBash filesystem remains authoritative for QID and lifecycle state.  Runtime evidence is correlated from:

```text
shared QueueBash .job record
immutable QueueExecutionJournal phases
recorded runner provider
provider-specific live/dead/unknown observation
durable PID / PGID / systemd-unit locator
durable exit-code locator
```

`QueueRuntimeMonitor` is read-only.  It never changes a job record and never treats provider evidence as queue authority.

## Typed runtime relations

Runtime relations are class-owned constants on `.QueueRuntimeRelation`:

```text
NONE
QUEUE_ONLY
PREPARED_ONLY
IN_SYNC
METADATA_MISSING
JOURNAL_MISSING
MULTIPLE_ACTIVE
EXECUTION_ID_MISMATCH
PROVIDER_UNAVAILABLE
QUEUE_TERMINAL
EXIT_PENDING
DEAD_WITHOUT_EXIT
OBSERVATION_DEFERRED
```

The corresponding `.QueueRuntimeAction` is one of:

```text
NONE
RECONCILE
DEFER
MANUAL_REVIEW
```

A read model may recommend `RECONCILE`; it does not itself perform reconciliation.

## Recovery rules

`QueueRuntimeRecoveryManager` is an internal/API surface.  It may call the already-qualified `QueueExecutionService~reconcile()` only when the projection has enough deterministic evidence to recommend reconciliation.

Examples:

- running record + exactly one durable PREPARED intent + missing execution metadata -> reconstruct metadata, never relaunch;
- running record + durable exit code -> reconcile to done/failed through the existing terminal/WLU authority path;
- provider `UNKNOWN` -> defer;
- provider dead with no durable exit -> manual review, never guess success/failure;
- duplicate queue QID or multiple active execution intents -> manual review;
- non-running QueueBash record -> QueueBash state wins; runtime evidence cannot reopen it.

## Read-only CLI

Dev9 exposes monitoring only:

```text
queuerexx runtime-status QID [--json]
queuerexx runtime-scan [--json]
```

`runtime-scan` is bounded and does not perform recovery.  There is intentionally no public `runtime-recover` command in dev10; dev10 fleet recovery remains an internal/API surface governed by the same typed recommendations.

## Provider ownership

Direct and systemd providers continue to own only mechanism-specific launch/observe/terminate behavior.  They do not own queue state.  This means runtime monitoring can be extended with future container/VM/remote providers without changing the queue lifecycle authority model.
