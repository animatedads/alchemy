# QueueBash 0.18.144 compatibility baseline

QueueRexx v0.1-dev8 targets the supplied `bashqueues_0.18.144_BOB27_lock_tree_ownership_hotfix_full_delivery.zip`.

The baseline adds or confirms these core behaviours that QueueRexx must preserve:

- exclusive pending record creation with collision retry;
- per-QID state transition locking;
- fresh missing launch metadata is deferred rather than interrupted;
- direct-run liveness accepts live PID or process-group evidence;
- systemd liveness treats `SYSTEMD_UNIT` / unit state / `MainPID` as authoritative;
- unknown/unqueryable systemd unit status defers rather than falling back to a dead launcher PID;
- known stale health/sentinel/policy-not-found duplicate state records are archived under `logs/queue-state-reconcile`;
- operator cancellations/deletions are not silently undone;
- both prefix and suffix `--force` cancel forms are accepted.

## State directories observed by current QueueBash

QueueRexx scans/preserves:

```text
pending
waiting
running
paused
done
failed
pol_blocked
interrupted
cancelled
deleted
```

`policy_blocked` is tolerated as a compatibility alias when encountered.

## Job record rule

QueueBash records are shell-style assignments produced heavily with `printf %q` and array forms such as:

```text
JOB_NAME=hello\ world
COMMAND=( /bin/echo a\ b )
```

QueueRexx does **not** source or evaluate these files. The native parser decodes the QueueBash quoting subset needed for values while retaining raw assignment text and unknown fields.

This is both a compatibility and security boundary: reading a job description must not execute shell syntax embedded in it.

## Qualification evidence in this dev increment

- the supplied `lock_tree_owner_repair_static.sh` and `lock_tree_owner_repair_smoke.sh` 0.18.144 hotfix tests pass on the extracted baseline;
- QueueRexx unit tests pass under ooRexx 5.3.0 r13196;
- a QueueBash-created job was read from the same queue root and the parsed object emitted by `queuerexx list --json` compared equal to the parsed object emitted by `queue list --json`.

## 0.18.144 ownership delta

QueueRexx dev8 retains lock-tree ownership as part of lock correctness. Mutation-side preparation creates `locks/`, `locks/state/`, and `logs/queue-state-reconcile/`, and when root operates a foreign-user queue it hands those paths back to the queue-root owner. A non-root actor that cannot write `locks/state` receives a typed `permission_denied` lock result rather than a misleading contention timeout.

`queuerexx diagnose QID --json` is deliberately non-mutating and reports lock-tree owner/writability together with duplicate-state evidence.


## WLU-managed records

QueueBash 0.18.144 does not implement WLU accounting. QueueRexx therefore keeps managed work QueueBash-compatible but non-executable until WLU/placement admission by staging it in `waiting` with `JOB_CLASS=QUEUEREXX_WLU_HOLD`. The requested class is retained in `WLU_ORIGINAL_JOB_CLASS`.

The shared hold class has a QueueBash-visible failing preflight, so QueueBash sentinel/`reevaluate` cannot unknowingly promote the job. QueueBash may still inspect or cancel the same shared record. A real QueueBash `cancel --force` mixed test proves QueueRexx subsequently repairs only WLU accounting and does not override QueueBash terminal state.
