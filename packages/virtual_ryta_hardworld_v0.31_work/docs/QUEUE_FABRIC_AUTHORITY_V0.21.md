# Queue Fabric authority execution boundary — v0.21 work

## Purpose

Queue transport is evidence about **how a unit of authority-bearing work arrived and was attempted**. It is not itself legal authority and it does not make a HardWorld mutation transactional.

The v0.21 work branch therefore adds a RYTA-owned execution boundary around `EvidencePromotionApplier` while consuming Queue Fabric v0.5 only through its actual public behavioural surface.

## Queue Fabric v0.5 identities actually used

`QueueWorkPackage` supplies:

```text
packageId
currentQueue
parentPackageId
state
claimedBy
claimToken
claimedAt
deliveryCount
backoutCount
```

A transfer receipt supplies:

```text
transferId
packageId
queueName
acceptedAt
sourceManager
duplicate
```

The receipt does **not** carry destination-manager identity. RYTA therefore requires the caller to provide an explicit execution namespace. It does not invent a Queue Fabric `attemptId`, `destinationManager` receipt field or queue session identifier.

For transferred work the stable replay key is based on:

```text
execution namespace + TRANSFER + transferId
```

For local work it is based on:

```text
execution namespace + LOCAL + queueName + packageId
```

The full work fingerprint additionally binds the package/queue/source provenance and the sealed `EvidencePromotionSet` canonical identity. Reusing one stable work key for a different promotion set fails with `WORK_IDENTITY_CONFLICT`.

## Receipt trust

A receipt-shaped caller object is insufficient. For transferred work, the executor calls Queue Fabric's public:

```text
manager~transferReceipt(transferId)
```

and requires the registered receipt to agree on `packageId`, `queueName` and `sourceManager`. The registered receipt object, not the caller-supplied lookalike, is retained as attempt provenance. The claimed `QueueWorkPackage` itself is **not** retained by RYTA because Queue Fabric leaves the claim token reachable from that object even after ACK. RYTA instead snapshots safe public transport metadata (`requestedQueue`, creation time, priority, persistence, security domain, routing/correlation/reply values) plus delivery/backout and claim principal/time.

## Claim token rule

`claimToken` is an acknowledgement capability, not evidence identity.

It is compared only in memory to verify the live claim before execution and is then supplied back to Queue Fabric for `ack`. It is not copied into:

```text
work identity
attempt canonical text
execution key
work fingerprint
ledger records
execution results (including raw Queue Fabric ACK result objects)
SQL-visible provenance
```

The focused regression checks both the raw token and its hex encoding are absent from the ledger, and asserts that RYTA result/evidence objects expose neither the claimed package nor the raw Queue Fabric ACK result.

## Why this is not exactly-once authority

Queue Fabric v0.5 can make transfer insertion idempotent through durable `transferId` receipts. It does not expose a transaction that atomically commits both:

```text
HardWorld mutation
queue ACK
```

RYTA therefore uses a small execution ledger:

```text
append START
    |
    v
EvidencePromotionApplier~apply(...)
    |
    v
append COMPLETE
    |
    v
Queue Fabric ACK
```

Recovery is intentionally asymmetric:

```text
no record
    -> begin normally

START only
    -> PREVIOUS_EXECUTION_UNCERTAIN
    -> do not apply again
    -> do not auto-ACK

COMPLETE
    -> suppress promotion replay
    -> ACK the currently claimed package
```

This sacrifices availability in the `START`/crash window rather than risking a duplicate authority-bearing mutation.

A `COMPLETE`/pre-ACK crash is recoverable: the mutation is not replayed and only acknowledgement is finished.

## Durability non-claims

The v0.21 ledger uses append-and-close records with strict rejection of an unterminated tail. It does not claim:

- `fsync`/power-loss durability;
- cross-process file locking;
- XA/distributed transactions;
- Queue Fabric UOW atomicity across HardWorld (the Queue UOW is queue-local and is not used as a fabricated cross-system transaction);
- atomicity with Queue Fabric's own journal;
- proof that a mutable in-memory HardWorld itself survived process loss.

Accordingly this is a **replay-safety/fail-closed boundary**, not an exactly-once commit protocol.

## Focused adversarial coverage

The executable v0.21 Queue Fabric integration proves:

- normal local START -> apply -> COMPLETE -> ACK;
- stable work key + changed promotion content is refused;
- START-only restart becomes `PREVIOUS_EXECUTION_UNCERTAIN` and does not mutate HardWorld;
- COMPLETE-before-ACK replay suppresses reapplication and completes ACK;
- real `transferId`/receipt provenance is retained;
- a fabricated/unregistered receipt is refused;
- a receipt that disagrees with Queue Fabric's registry is refused;
- execution namespace is mandatory;
- a permanent Queue Fabric transfer receipt survives manager restart;
- duplicate durable transfer after restart does not reinsert consumed work;
- `claimToken` does not leak into the RYTA ledger.

## Package boundary

No Queue Fabric, Runtime Registry, Legal Effect or NoSQLServer source is modified or vendored. This integration remains owned by Virtual RYTA / HardWorld.
