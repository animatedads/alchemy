# Authority lifetime and completed-work handoff — RYTA v0.26-work

## Rule

Consumer-time authority is required to **perform an authority-bearing side effect**. It is not a permanent capability, and it is not required again merely to acknowledge transport for a side effect already durably recorded as complete.

```text
immutable work envelope identity
        !=
authority decision used to execute it
        !=
queue delivery attempt
```

This distinction closes two different replay hazards.

1. A consumer-time revalidation result minted for one Queue Fabric claim must not be reused by a later claim, another package, or another subscriber.
2. If HardWorld application reached durable `COMPLETE` but Queue Fabric ACK failed, later policy/revocation must not strand the already-performed side effect. The retry may ACK only, but only after proving the immutable submitted work envelope is the same one that completed.

## V2 execution ledger

`QueueAuthorityExecutionLedger` now supports `RYTA_QUEUE_AUTHORITY_LEDGER_V2` records containing two independent fingerprints:

- **work envelope fingerprint** — stable Queue work identity + publisher-supplied sealed promotion set + native retained/publication identity;
- **authority decision fingerprint** — the promotion set actually applied plus stable consumer-time revalidation semantics.

The V2 sequence is:

```text
claim
  |
  +--> build immutable envelope fingerprint
  |
  +--> ledger preflight
          |
          +-- COMPLETE + envelope match --> ACK only
          |
          +-- COMPLETE + envelope mismatch --> WORK_ENVELOPE_CONFLICT
          |
          +-- START --> PREVIOUS_EXECUTION_UNCERTAIN
          |
          `-- NONE
                |
                v
         consumer-time authority
                |
                v
         authority fingerprint
                |
                v
        START -> apply -> COMPLETE -> ACK
```

A V2 `COMPLETE` retry does **not** call the consumer revalidator and does not invoke `EvidencePromotionApplier`. It mints no new authority evidence. It is transport cleanup only.

V1 records remain readable and the old `begin` / `complete` API remains supported for recovery. Because V1 does not contain the independent immutable-envelope fingerprint, V1 `COMPLETE` recovery keeps the conservative legacy behavior and must reproduce the old authority fingerprint before ACK.

## Per-attempt consumer authority binding

`QueueAuthorityRevalidationResult` now carries two separate execution-binding fields:

- `workExecutionKey` — the RYTA stable Queue work key;
- `attemptIdentity` — SHA-256 over `QueueAuthorityAttemptEvidence` (delivery count, backout count, claimant and claim time, but never the bearer-like claim token).

Successful retained-event revalidation is rejected unless both match the current claimed package.

The fields are intentionally **not** part of `algorithmCanonicalText`, because they are delivery freshness, not the stable semantic authority decision. `executionBindingCanonicalText` exposes them separately for audit.

This permits a second delivery attempt to obtain a fresh binding while leaving the durable authority-decision fingerprint stable when the current legal/policy result is semantically unchanged.

## Legal Effect v0.10 proof

The executable Legal v0.10 test demonstrates both sides of the boundary:

1. A retained event is evaluated under a live `LegalRuntimeRuleLease`; the HardWorld mutation succeeds; the test Queue Manager deliberately fails ACK; V2 records `COMPLETE`.
2. The Legal runtime lease is released before redelivery. The same immutable work envelope is redelivered with a new Queue claim. RYTA detects the previous `COMPLETE`, does not invoke the now-invalid Legal revalidator, performs no HardWorld apply, and ACKs the package.
3. A different retained work item presented after the lease release still fails at fresh Legal evaluation with `LEGAL_RETAINED_LIVE_EVALUATION_REFUSED` / `LEGAL_LEASE_RELEASED` before ledger `START`.

Thus release/revocation does not retroactively convert completed work into unacknowledgeable transport debt, and completed-work ACK recovery does not create authority for any new work.

## Security invariants

- `claimToken` remains absent from canonical text, hashes, ledger records and returned evidence.
- A cached successful revalidation from delivery attempt 1 is refused on delivery attempt 2.
- A cached successful revalidation from one subscriber/package is refused on another work identity.
- A tampered publisher promotion set cannot exploit an existing `COMPLETE` record to receive a blind ACK.
- `START` without `COMPLETE` remains `PREVIOUS_EXECUTION_UNCERTAIN`; V2 does not claim XA or exactly-once mutation.
