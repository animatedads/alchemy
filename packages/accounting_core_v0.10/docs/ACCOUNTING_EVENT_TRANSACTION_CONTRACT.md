# Accounting event and transaction contract v0.6

## Purpose

Operational systems do not post accounting journals directly in the normal integration path. They emit an `AccountingEvent` describing authoritative business evidence. A legal-entity accounting policy maps that event into a journal draft, and Accounting Core validates and posts the result.

```text
operational authority
      |
      | AccountingEvent
      v
AccountingEngine~transact()
      |
      +--> exact legal entity check
      +--> source-event replay/conflict check
      +--> effective-dated policy resolution
      +--> executable accounting policy
      +--> policy/source binding validation
      v
AccountingBook~post()
      |
      +--> period controls
      +--> chart validation
      +--> per-currency double-entry balance
      v
immutable AccountingJournalEntry
```

`AccountingEngine~post()` / `postDraft()` remain lower-level controlled APIs for accountant/manual/migration tooling. Demo operational engines should normally use `transact()`.

## AccountingEvent

An event contains:

- `sourceEventRef` — stable identity assigned by the operational source
- `legalEntityId` — the company whose accounting consequence is being requested
- `eventType` — stable semantic event kind used for accounting-policy resolution
- `eventDate` — economic/effective date used to select the policy generation
- `correlationRef` — optional common economic-chain identity shared across companies
- `counterpartyEntityId` — optional counterparty identity for this company's side
- `sourceAuthorityRef` — identity of the operational authority emitting the evidence
- `payload` — normalized event facts, recursively detached from caller mutation
- `evidenceRefs` — immutable references to source evidence
- `metadata` — additional normalized context

The event fingerprint covers all of those values recursively. The accounting engine stores that fingerprint on the resulting posted journal.

## Replay and recovery invariant

An already-accounted `sourceEventRef` is checked **before accounting policy is executed**.

- same source reference + same event fingerprint -> `DUPLICATE`, original journal returned
- same source reference + changed event fingerprint -> `SOURCE_EVENT_CONFLICT`
- an old low-level posting with no event fingerprint cannot be silently adopted into the event path

This means replay after a software/policy upgrade cannot reinterpret a historical source event using a newer accounting policy.

## Executable accounting policy identity

Each registered `AccountingPolicy` has two identities:

- `policyRef` — semantic/versioned policy reference, e.g. `vmm.accounting.derivative-fv/0.3`
- `policyIdentity` — immutable identity of the exact executable implementation/artifact used

Both are retained on the journal. The executable identity is deliberately supplied rather than guessed from a class name. Deployments may use a semantic-source-control digest, Runtime Registry artifact identity, signed bundle identity or another immutable code-evidence reference.

Policies are effective-dated by legal entity + event type. Overlapping policy ranges for the same legal entity/event type are rejected by `AccountingPolicyCatalog`, making resolution deterministic.

## Policy proposal binding

An accepted policy draft must remain bound to the event and selected policy. `AccountingEngine~transact()` checks:

- source event reference
- economic correlation reference
- policy reference
- exact executable policy identity
- source-event fingerprint
- event type
- counterparty
- preservation of event evidence references
- source-authority evidence stamp

A policy cannot manufacture a detached journal and have it accepted as the consequence of another event.

## Company isolation

A company's `AccountingEngine` rejects an event naming another `legalEntityId`.

A common `correlationRef` is deliberately allowed across companies. It connects evidence for later reconciliation but provides no authority to post another company's books.

For example:

```text
ECONOMIC-CHAIN-001
  FlyLo      -> FLYLO-J...
  Federation -> FED-J...
  All Japan  -> AJI-J...
  VMM        -> VMM-J...
```

Those are four independent journal entries. They can differ in amount, timing, classification, recognition basis and accounting policy while still being connected to the same wider economic chain.

## Policy extensibility

The accounting core does not interpret payload meanings. Entity policy may use authoritative evidence concerning:

- legal versus beneficial ownership
- trusts/SPVs
- encumbrance and hypothecation/rehypothecation
- collateral control
- reinsurance
- derivative valuation
- revenue recognition
- consolidation/elimination
- regulatory or management reporting bases

The policy expresses the accounting treatment. Core only enforces the mechanics and evidence binding.


## Numeric precision compatibility

Accounting policy execution is part of accounting arithmetic and must not run at ooRexx's default 9-digit precision.

Every policy source package must declare:

```rexx
::OPTIONS DIGITS 50
```

`AccountingPolicyCatalog~register()` inspects the defining package of the concrete policy class and rejects packages with fewer than 50 digits. This requirement applies to FlyLo, Federation, All Japan, VMM and any future legal-entity policy package.

The core itself also compiles with `::OPTIONS DIGITS 50`, while critical amount/balance paths issue `numeric digits 50` explicitly.

See `PERSISTENCE_AND_PRECISION.md`.
