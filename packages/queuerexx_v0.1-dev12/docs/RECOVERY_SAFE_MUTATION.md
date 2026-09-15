# Recovery-safe mutation kernel

## Authority

The `.queuebash` job record is authoritative. SQL, event indexes, transition journals and observations are derived evidence.

## QID locking

QueueRexx uses the QueueBash 0.18.144 layout:

```text
locks/state/<QID>.lock/
  meta
```

`meta` contains `pid`, `created_at`, and `actor`. Lock acquisition is atomic directory creation. A lock with a live owner PID is never stolen. A dead numeric owner PID may be reclaimed. Missing or malformed owner evidence is not guessed stale.

## Exclusive pending allocation

QueueRexx generates a QID, takes its state lock, verifies no existing state record, then performs true no-overwrite creation in the QueueBash priority bucket. Collision causes bounded regeneration/retry; never overwrite or merge.

## Transition transaction

A transition is a filesystem transaction with a durable evidence sidecar:

1. acquire QID lock;
2. verify exactly one source record;
3. verify source state and destination absence;
4. persist immutable `prepared` JSON through stock ooRexx `.JSON`;
5. atomically rename source record to destination;
6. persist immutable `committed` JSON;
7. append QueueBash-compatible `events.jsonl` through stock `.JSON`;
8. persist immutable `event_recorded` JSON;
9. release lock.

## Crash matrix

For a prepared transaction without a terminal marker:

| Source | Destination | Recovery |
|---|---|---|
| present | absent | `ABORTED` — authoritative move did not commit |
| absent | present | `RECOVERED` — authoritative move committed |
| present | present | `AMBIGUOUS` — do not delete or choose |
| absent | absent | `AMBIGUOUS` — evidence lost/inconsistent |

Recovery takes the same QID lock before interpreting the evidence. A committed/recovered transition whose event marker is missing is completed idempotently: QueueRexx parses the shared QueueBash JSONL with `.JSON`, searches for the transaction identifier embedded in the compatible `detail` field, and appends only when that event is not already present. This closes the process-crash window between event append and its sidecar marker without extending the QueueBash event schema.

Dev3 qualifies process-crash/restart recovery. It does not yet claim storage-controller/power-loss durability equivalent to an explicitly fsync-backed transactional store; that stronger durability can be added behind the atomic-filesystem provider without changing transition semantics.

## Why Journal Pointed State is not the durable transition log

The supplied Journal Pointed State v0.1 is an excellent in-process branching/reversible state primitive, but its own design states that durable/freeze persistence is an external boundary. QueueRexx therefore keeps the durable transition evidence as explicit filesystem JSON sidecars and may use Journal Pointed State later for in-process orchestration/checkpoint reasoning without confusing those authority levels.
