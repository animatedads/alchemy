# Accounting Core v0.10 architecture

## 1. Legal-entity boundary

Accounting Core is shared infrastructure, **not a shared ledger**. Each legal entity owns an independent `AccountingEngine` and `AccountingBook`.

```text
operational authority                         accounting authority
---------------------                         --------------------
FlyLo booking/ancillary event  --policy-->    FlyLo AccountingBook
All Japan policy/claim event    --policy-->    AJI AccountingBook
VMM trade/valuation event       --policy-->    VMM AccountingBook
Federation business event       --policy-->    Federation AccountingBook
```

A common economic/correlation reference may connect all sides. It never grants one company authority to write another company's books.

## 2. Operational event boundary

v0.3 introduced the preferred operational integration path:

```text
source operational event
        |
        v
AccountingEvent / accounting.event/0.1 projection
        |
        v
AccountingEngine~transact()
        |
        +-- legalEntityId exact match
        +-- source-event replay/conflict guard
        +-- effective accounting-policy resolution
        +-- policy execution
        +-- policy/event/evidence binding validation
        v
AccountingBook~post()
        |
        +-- chart + period controls
        +-- currency/account checks
        +-- independent balance by currency
        v
immutable AccountingJournalEntry
```

`transactProjection()` allows a normalized Directory/JSON-shaped event contract to enter the same path, leaving future Queue Fabric/Runtime Registry adapters free of ooRexx object-sharing assumptions.

## 3. Event identity and recovery

`AccountingEvent~fingerprint` covers:

- source event reference
- legal entity
- event type and event date
- economic correlation reference
- counterparty
- operational source-authority reference
- recursively normalized payload
- evidence references
- metadata

Nested directories/arrays are detached recursively when copied into the event.

Before executing accounting policy, the engine checks whether the source reference was already posted:

```text
same ref + same fingerprint     -> DUPLICATE, return original journal
same ref + changed fingerprint  -> SOURCE_EVENT_CONFLICT
```

This ordering matters. Historical recovery must not rerun an old event through a newer accounting policy and silently reinterpret history.

## 4. Executable accounting policy

The core invariant remains:

> Accounting Core enforces mechanics. It does not decide the legal/economic substance or accounting treatment of the source transaction.

`AccountingPolicyCatalog` resolves policies by:

- legal entity
- event type
- event date inside the policy's effective range

Overlapping effective ranges for the same entity/event type are rejected.

Every policy has:

- `policyRef` — semantic/versioned accounting-policy reference
- `policyIdentity` — exact immutable executable/artifact identity

The journal retains both. `policyIdentity` is intentionally supplied by deployment/integration rather than guessed from a class name, allowing future use of Semantic Source Control identities, Runtime Registry artifact identities, signed package digests or equivalent evidence.

Entity policy may inspect authoritative evidence about ownership, trusts, collateral, encumbrance, reinsurance, derivatives, consolidation or anything else. Those meanings are not hard-coded into the core engine.

## 5. Proposal binding

A policy decision may accept or reject an event. An accepted `AccountingJournalDraft` is checked against the event and selected policy before posting.

The binding includes:

- sourceEventRef
- correlationRef
- policyRef
- policyIdentity
- sourceEventFingerprint
- eventType
- counterpartyEntityId
- all source evidence refs
- source-authority stamp

This prevents a policy from presenting a journal detached from the evidence it supposedly accounted for.

## 6. Low-level posting remains available

`AccountingBook~post()` and `AccountingEngine~post()/postDraft()` remain valid lower-level APIs. They support explicit manual/accountant/migration workflows and preserve v0.1/v0.2 usage.

A low-level posting can omit `policyIdentity` and event fingerprint. Such an entry is intentionally **not silently adopted** as an event-transaction entry later; replay through `transact()` reports that source event identity is unavailable.

## 7. Native posting mechanics

`AccountingBook` enforces:

- known/active accounts
- open accounting period and date membership
- at least two journal lines
- whole non-negative minor-unit debit/credit amounts
- no line containing both debit and credit
- independent balance per currency
- configured `SINGLE` account currency
- source-reference idempotency
- immutable entry retention
- reversal by new journal, never mutation

Multi-currency journals are valid only when each currency balances separately. FX valuation/translation differences therefore require explicit policy-produced accounting lines.

## 8. Open legal/economic dimensions

Journal lines retain arbitrary dimensions. Examples include:

- `legalOwner`
- `beneficialOwner`
- `economicRiskBearer`
- `controller`
- `trustOrVehicleRef`
- `encumbranceRef`
- `counterpartyRef`
- `valuationBasis`
- `reportingBasis`

The VMM demo can therefore retain `CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3` and a rehypothecation facility on VMM's lines without causing the core to understand Cayman trust law or contaminating FlyLo's ledger.

## 9. Orthogonal statutory scopes

The legal entity is not the tax jurisdiction, place of business or regulatory
perimeter. v0.5 standardises optional journal-line references for those
orthogonal relationships.

```text
LegalEntity
  +-- Establishment(s)
  +-- TaxRegistration(s)
  |     `-- effective-dated TaxElection(s)
  +-- RegulatoryRegistration(s)
  +-- ClientMoneyArrangement(s)
  `-- AccountingBook(s)
```

`TaxRegistration` is stable statutory identity. `TaxElection` is effective-dated calculation/reporting configuration with a semantic/version reference plus immutable election identity, and retains exact ruleset identity, rounding algorithm, calculation granularity and return scheme. This allows a change in an
elected method without fabricating a new VAT/GST registration.

The core validates references and consistency but does not calculate VAT/GST or
implement regulator-specific rules. Those remain external policy modules.

`accounting.relationshipKind` explicitly distinguishes `INTER_ESTABLISHMENT`
from `INTERCOMPANY`; a branch transfer does not create an intercompany balance.

## 10. Reporting boundaries

`AccountingReportingBoundary` is a version/evidence-bearing selector over
immutable books and journal dimensions. It can include multiple legal entities
or books when a regulator/reporting policy requires that perimeter.

A reporting view does not post, rewrite or copy accounting transactions. It
retains the exact boundary fingerprint and aggregates exact minor-unit amounts by
currency/account. Thus tax returns, professional-regulator reports, client-money
reconciliations and management accounts can be different views of the same
underlying economic books.

## 11. Generic tax determination

v0.6 inserts a tax-determination boundary between supply evidence and accounting treatment without moving jurisdiction law into the ledger.

```text
supply evidence
   -> AccountingTaxRequest
   -> active TaxRegistration + effective TaxElection
   -> exact rulesetIdentity
   -> jurisdiction AccountingTaxPolicy
   -> AccountingTaxDetermination
   -> ordinary AccountingEvent
   -> entity AccountingPolicy
   -> AccountingBook
```

A tax policy decides taxability, rate/fraction, formula and how the elected rounding method is applied. The core supplies exact rational arithmetic and generic quantization mechanics only. `taxPolicyIdentity`, `rulesetIdentity`, election identity and the pre-round exact fraction are retained as evidence.

Tax requests and determinations have normalized transport contracts so a queue or gateway need not share ooRexx objects. Once a determination is posted, `transactTax()` checks the persisted tax-request fingerprint before any tax-policy or accounting-policy redispatch, preserving historical interpretation across restart.

See `docs/TAX_DETERMINATION_CONTRACT.md`.

## 12. Four-company chain

The packaged acceptance locks the intended isolation semantics:

```text
                    ECONOMIC-CHAIN-001
                           |
        +------------------+------------------+
        |                  |                  |
      FlyLo            Federation         All Japan             VMM
 AccountingBook      AccountingBook      AccountingBook      AccountingBook
```

All four may use one correlation reference. Each has its own source index, policy catalogue, chart, periods and journal sequence. The same source token can exist independently in several legal-entity books because source identity is scoped by book authority, not globally.

## 13. External assessment authority remains separate

`AccountingAssessmentBook` remains deliberately distinct from `AccountingBook`.

```text
Companies House source document
        |
        v
Civic retrieval + immutable evidence + mapping
        |
        v
accounting.civic.companieshouse/0.2
        |
        v
AccountingAssessmentBook
        |
        v
assessment policy
```

There is no implicit path from a filed statement to native GL posting.

The retained WALKABOUT LTD fixture proves that assessment can preserve balance-sheet facts, dimensional XBRL evidence, reporting policies, director advances, share classes and filing-completeness statements. In particular, an Income Statement explicitly not delivered under section 444 is represented as **not filed**, not zero.

## 14. Ecosystem seams

Accounting Core remains standalone in v0.6, but its boundaries align with the supplied ecosystem:

- **Queue Fabric** can transport `accounting.event/0.1` projections.
- **Runtime Registry / Semantic Source Control** can provide exact `policyIdentity` artifact evidence.
- **Institutional Policy** can govern who may publish/activate policy identities without becoming accounting treatment itself.
- **Legal Effect** can supply legal/economic evidence consumed by entity accounting policy without being replaced by Accounting.
- **Civic** remains responsible for public-data retrieval and source normalization.

Those integrations can be added without changing the accounting authority boundaries above.


## 15. Arithmetic profile

Accounting Core v0.6 fixes the accounting arithmetic profile at:

- exact integer minor units
- `NUMERIC DIGITS 50`
- package directive `::OPTIONS DIGITS 50`
- rejection of amounts wider than 50 significant integer digits

ooRexx method activations normally start from their source package's numeric settings rather than inheriting the caller's setting. Therefore an entity-specific `AccountingPolicy` package is accepted only when `policy~class~package~digits >= 50`.

This makes precision part of executable policy compatibility. A policy compiled at the ooRexx default of 9 digits is not allowed to determine accounting consequences.

## 16. Durable store

`accounting.store/0.1` defines the first durable-book implementation.

```text
AccountingBook
   |
   +-- chart mutation --------+
   +-- period mutation -------+--> AccountingFileStore
   +-- journal post ----------+       append-only JSONL
   |                          |
   +<--------- recovery ------+
```

The first record binds legal entity, book, reporting basis and arithmetic profile. Subsequent records append chart, period, period-transition and journal mutations in deterministic sequence.

For persistent books, existing surfaces such as `book~chart~add()`, `book~chart~seal` and `period~close()` remain usable: the chart and period objects are attached to their owning book and invoke persistence hooks before mutation.

Journal amounts use logical `I:<integer>` strings and a physical `S:` scalar-protection layer in JSONL (`S:I:<integer>`). Numeric-looking opaque strings are protected by the same `S:` layer, so leading zeroes cannot be lost.

Recovery validates record sequence and arithmetic profile, replays into a fresh in-memory book with persistence temporarily detached, verifies deterministic journal entry/fingerprint identity, and finally reattaches the store.

The recovered source index preserves the transaction invariant: an exact operational-event replay is returned as `DUPLICATE` before policy dispatch; changed reuse remains `SOURCE_EVENT_CONFLICT`.

Period transitions are accounting evidence. A close/reopen/lock transition retains its prior/new state, actor, rationale, evidence references and supplied occurrence time. A `LOCKED` period cannot subsequently change state.


## Settlement rounding boundary (v0.7)

Settlement rounding is a separate policy boundary after the obligation/tax amount exists. The core records the exact pre-settlement amount, exact election/ruleset/executable identities, tender applicability, quantum and signed difference. The resulting company accounting event may clear receivable/payable and recognize a separate rounding difference, but settlement policy cannot mutate a prior tax determination.


## 10. Sealed reporting evidence (v0.8)

`AccountingReportingView` remains a live selector. `AccountingReportingSnapshot` freezes the exact boundary fingerprint, selected line identities and the ordered journal cutoff of each source book. Verification treats append-only advancement outside the report perimeter as visible-but-valid, while a later/backdated in-perimeter journal marks the old population `REPORT_POPULATION_STALE`.

A boundary may span books and legal entities, but every reporting line preserves its original legal entity and book. Consolidation, elimination and regulator-specific presentation remain policy-layer concerns. Generic dimension aggregation never combines currencies.


## 17. Reporting attestation and filing evidence (v0.9)

A sealed reporting snapshot is accounting evidence; an approval/signature and a regulator receipt are separate evidence about that snapshot. v0.9 therefore adds a layer above `accounting.reporting.snapshot/0.1` rather than changing the book or reporting boundary.

```text
AccountingBook(s)
   -> ReportingBoundary
   -> sealed ReportingSnapshot
   -> Attestation(s) [attestor + authority identity + proof/key identity]
   -> SubmissionEvidence [exact attestation set + external receipt identity]
```

Accounting does not decide that the attestor owns a key or has legal permission to sign. It freezes those claims inside the proof payload. Crypto proves integrity/attribution; Access Permissions/Security Effect/Institutional Policy/Legal Effect or regulator policy can establish whether the asserted authority was valid.

Historical correction does not rewrite filing history. `REPORT_POPULATION_STALE` may coexist with a still-valid attestation and submission receipt for the immutable old snapshot.

## 18. Filing lifecycle is evidence, not mutation

v0.10 introduces a filing version and append-only lifecycle above sealed reporting snapshots and v0.9 attestation/submission evidence.

```text
AccountingReportingSnapshot
   -> AccountingReportingAttestation(s)
   -> AccountingReportingSubmissionEvidence
   -> AccountingReportingFilingVersion
   -> AccountingReportingLifecycleEvent*
```

A filing is an immutable version in a logical reporting series. `AMENDMENT` and `CORRECTION` versions point to the exact predecessor filing fingerprint. Regulator/workflow state is derived from ordered lifecycle observations rather than by mutating a status field on the filing or submission.

`REJECTED`, `WITHDRAWN` and `SUPERSEDED` therefore preserve the historical artifact and evidence. A corrected filing may supersede an earlier stale/rejected filing and resubmit against the exact earlier submission-event identity. The old signature, submission receipt and rejection remain evidence of what actually happened.

Actor and semantic authority identities are frozen in each event, but validity of that authority remains outside Accounting Core.

See `docs/REPORTING_LIFECYCLE_CONTRACT.md`.
