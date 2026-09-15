# Accounting Core v0.10

Reusable ooRexx accounting infrastructure for independent legal-entity books, versioned executable accounting-policy dispatch, and evidence-safe assessment of external financial statements.

Accounting Core is **not** a banking engine, insurer policy engine, airline booking engine, trading engine or Companies House client. Each demo company owns its own `AccountingEngine`; operational systems remain authoritative for operational facts, while Accounting owns that entity's posted accounting truth.

## APIs

- core mechanics: `accounting.core/0.1`
- posting: `accounting.posting/0.2`
- operational event projection: `accounting.event/0.1`
- event -> policy -> journal transaction path: `accounting.transaction/0.1`
- external assessment: `accounting.assessment/0.2`
- durable store: `accounting.store/0.1`
- statutory/accounting scopes: `accounting.scope/0.1`
- reporting boundaries/views: `accounting.reporting/0.1`
- sealed evidential reporting snapshots: `accounting.reporting.snapshot/0.1`
- reporting attestations: `accounting.reporting.attestation/0.1`
- reporting submission/receipt evidence: `accounting.reporting.submission/0.1`
- immutable filing versions: `accounting.reporting.filing/0.1`
- append-only reporting lifecycle: `accounting.reporting.lifecycle/0.1`
- generic tax determination: `accounting.tax/0.1`
- tax request projection: `accounting.tax.request/0.1`
- tax determination projection: `accounting.tax.determination/0.1`
- settlement rounding: `accounting.settlement/0.1`
- settlement request projection: `accounting.settlement.request/0.1`
- settlement determination projection: `accounting.settlement.determination/0.1`
- Civic Companies House adapter: `accounting.civic.companieshouse/0.2`
- Companies House assessment policy: `accounting.assessment.companieshouse/0.1`

## Preferred company integration

```text
FlyLo / All Japan / Federation / VMM operational authority
                       |
                       | accounting.event/0.1
                       v
              AccountingEngine~transact()
                       |
                 exact entity check
                 replay/conflict guard
                 effective-dated policy
                 executable identity lock
                 source/evidence binding
                       |
                       v
                AccountingBook~post()
                       |
                 immutable journal
```

Operational engines should normally emit `AccountingEvent` or its normalized directory/JSON-shaped projection and call `transact()` / `transactProjection()`.

`post()` / `postDraft()` remain deliberately available as lower-level controlled accounting APIs for explicit accountant/manual/migration workflows. They are not the normal operational-system integration boundary.

## Transaction guarantees

1. Every event names the legal entity whose books may be affected. Cross-company events are rejected.
2. Event identity covers source reference, entity, event type/date, correlation, counterparty, source authority, payload, evidence and metadata.
3. Nested payload/evidence structures are recursively detached from caller mutation.
4. Source-event replay is checked before policy execution. Exact replay returns the original entry; changed reuse is a conflict.
5. Accounting policies are resolved by exact legal entity + event type + event date.
6. Overlapping effective policy ranges for the same entity/event type are rejected.
7. `policyRef` identifies the accounting rule generation; `policyIdentity` locks the exact executable/artifact identity that produced the journal.
8. An accepted policy draft must remain bound to the source event, correlation, executable identity, counterparty, evidence and source authority.
9. Closed periods, unknown accounts, currency errors and unbalanced journals remain posting-mechanics failures after policy treatment is selected.
10. `SINGLE`-currency accounts enforce their configured currency.
11. Accounting policy source packages must compile with `::OPTIONS DIGITS 50`; lower-precision packages are rejected at registration.

See `docs/ACCOUNTING_EVENT_TRANSACTION_CONTRACT.md`.




## Sealed regulatory/statutory reporting snapshots

v0.8 keeps live `AccountingReportingView` behaviour and adds `AccountingReportingSnapshot` for evidential reporting. A snapshot freezes the exact reporting-boundary identity, selected immutable journal lines, and the complete ordered source-journal cutoff for each included book. `verifySnapshot()` distinguishes an unchanged source, harmless later source advancement, and a later/backdated journal that makes the previously sealed population incomplete.

Legal-entity and book identities remain on every reporting line; multi-entity reporting therefore does not imply consolidation or elimination. Generic `totalsByDimensions()` supports client-money, establishment, tax-registration, regulatory-registration, matter and arbitrary company dimensions while keeping currency separate.

See `docs/SEALED_REPORTING_SNAPSHOT_CONTRACT.md` and `examples/regulated_reporting_snapshot_demo.rex`.

## Reporting attestation and submission evidence

v0.9 binds external approval/signature evidence to an exact sealed reporting snapshot without making Accounting Core an identity, permission or regulator system. The attestation payload includes the snapshot fingerprint, boundary fingerprint, attestor, exact authority identity, proof/key identities, purpose, occurrence time and evidence. `verifyAttestation()` checks structural binding and delegates proof verification to an algorithm-neutral provider.

The optional `AccountingReportingCrypto.cls` adapter qualifies SHA-256 + Ed25519 against ooRexx Crypto v0.8.3. `AccountingReportingSubmissionEvidence` separately freezes the exact attestation set and regulator submission/receipt identities. A later backdated journal may make the old report `REPORT_POPULATION_STALE` while the old signature and receipt remain valid proof of what was actually filed.

See `docs/REPORTING_ATTESTATION_SUBMISSION_CONTRACT.md` and `examples/regulated_reporting_attestation_demo.rex`.

## Reporting filing lifecycle

v0.10 adds immutable filing-version lineage and append-only regulator/workflow observations above the v0.8/v0.9 snapshot, attestation and submission layers. An `ORIGINAL`, `AMENDMENT` or `CORRECTION` binds one exact snapshot and exact attestation set; amendments/corrections also bind the exact predecessor filing fingerprint.

`AccountingReportingLifecycle` records `SUBMITTED`, `RESUBMITTED`, `ACKNOWLEDGED`, `ACCEPTED`, `REJECTED`, `WITHDRAWN` and `SUPERSEDED` events as an ordered fingerprint chain. Rejection, withdrawal and supersession never delete or rewrite the original snapshot, approval or submission evidence. Regulator acknowledgement/decision observations require exact external evidence identities, while actor authority remains an external Access/Permissions/Legal Effect concern.

A corrected filing can therefore supersede a stale/rejected original and explicitly resubmit against the exact prior submission event while the historical filing remains independently verifiable.

See `docs/REPORTING_LIFECYCLE_CONTRACT.md` and `examples/regulated_reporting_lifecycle_demo.rex`.

## Settlement rounding versus tax rounding

v0.7 keeps settlement rounding completely separate from tax determination. `AccountingSettlementRoundingElection` freezes an effective-dated jurisdiction/currency/tender scope, exact ruleset identity, rounding algorithm reference and integer-minor-unit quantum. The core does not infer `cash => rounding`: an election may apply to all tenders, physical cash only, or another explicit tender set.

`AccountingEngine~determineSettlement()` dispatches the exact external settlement ruleset and produces an evidence-bound determination containing the already-accounted amount, settled amount and signed rounding difference. `transactSettlement()` then enters the ordinary company accounting-policy path; the company's policy decides whether the difference is a gain, loss or another accounting treatment.

A settlement determination can never rewrite VAT/GST/tax already determined on the invoice. v0.7 also adds neutral `HALF_EVEN` arithmetic alongside the existing primitives, and quantum rounding remains exact under `DIGITS 50`.

See `docs/SETTLEMENT_ROUNDING_CONTRACT.md` and `examples/settlement_rounding_demo.rex`.

## Generic tax determination

v0.6 adds a tax layer on the existing v0.5 registration/election model without putting UK VAT, Australian GST or any other jurisdiction's substantive rules in Accounting Core.

`AccountingEngine~determineTax()` resolves the active registration/election and dispatches an external `AccountingTaxPolicy` by the election's **exact ruleset identity**. The policy returns an evidence-bound `AccountingTaxDetermination`. `transactTax()` then converts that determination into the ordinary accounting-event path; the company's `AccountingPolicy` still decides the GL entries.

Tax arithmetic can retain fractions of a minor unit exactly as integer numerator/denominator under `DIGITS 50`. Generic quantization/rounding mechanics are reusable, while the jurisdiction pack decides which method is legally applicable and when.

Once a tax determination has been posted, replay uses the persisted tax-request fingerprint before either tax or accounting policy dispatch. An old invoice cannot therefore be reinterpreted merely because a newer tax ruleset is now loaded.

The qualification includes one GB VAT and one Australian GST ruleset using the same core, plus a foreign seller carrying a GB VAT registration without a fictional UK company. These are interface examples, not complete tax-law packs.

See `docs/TAX_DETERMINATION_CONTRACT.md` and `examples/tax_determination_demo.rex`.

## Orthogonal statutory scopes and reporting boundaries

v0.5 adds first-class, independent objects for:

- establishments / places of business
- tax registrations
- effective-dated tax elections
- professional/regulatory registrations
- client-money arrangements
- reporting boundaries

They do **not** redefine the legal entity. A foreign company can hold a UK VAT
registration without a fictional UK company or UK establishment, and one legal
entity can hold simultaneous UK VAT, Australian GST and professional-regulator
registrations while posting to one economic book.

Tax registration and tax election are deliberately separate. The registration
identifies the statutory relationship and registration number. The election
freezes the applicable ruleset identity, rounding algorithm, calculation
granularity and return scheme for an effective period. Once a current election exists, a tax-tagged journal line must retain both its semantic/version `accounting.taxElectionRef` and immutable `accounting.taxElectionIdentity`.

`AccountingReportingBoundary` derives immutable views by legal entity, book and
exact journal-line dimensions. The same journals can therefore support a UK VAT
view, an Australian GST view, a holistic professional-regulator Client Account
view and whole-firm management accounts without copying or reposting entries.

See `docs/SCOPES_AND_REPORTING_BOUNDARIES.md` and
`examples/dual_jurisdiction_law_firm_demo.rex`.

## v0.4.1 sibling reconciliation

The separately supplied v0.3.1 branch fixed institutional-scale exact minor-unit validation by entering `numeric digits 50` before `DATATYPE(..., "W")`. v0.4 already contains that fix and goes further with the 50-digit arithmetic profile and durable integer-string representation. v0.5 formally reconciles the branch by retaining its 12,000,000,000-minor-unit transaction regression alongside the stronger 40-digit JPY qualification.

## v0.4 precision and durable-book guarantees

Accounting money is represented as exact whole-number **minor units** and all Accounting Core ooRexx source packages compile with:

```rexx
::OPTIONS DIGITS 50
```

Critical arithmetic methods also issue `numeric digits 50` explicitly. This is an accounting contract, not a display preference.

This matters especially for JPY and large-notional books: the default ooRexx precision is 9 digits, and method activations do not automatically inherit the caller's numeric setting. Entity accounting-policy packages therefore also have to declare `::OPTIONS DIGITS 50`; `AccountingPolicyCatalog~register()` rejects a policy package compiled below 50 digits.

Amounts wider than 50 significant integer digits are rejected rather than silently rounded.

Durable books use `AccountingFileStore`, an append-only JSONL record stream. The store persists:

- book/legal-entity/reporting-basis identity
- exact arithmetic profile and `NUMERIC DIGITS` setting
- chart additions and chart seal
- accounting periods
- period state transitions, actor/reason/evidence/time
- immutable posted journal drafts and deterministic entry identities
- source-event fingerprints used for restart-safe idempotency
- journal evidence, metadata and dimensions

Money is **never emitted as a JSON number**. Logical journal amounts use an `I:<integer>` encoding, and the store's scalar-protection layer prefixes persisted Rexx scalar strings with `S:`. A physical JSONL record therefore contains values such as:

```json
{"debit_minor":"S:I:1234567890123456789012345678901234567890"}
```

The `S:` layer also preserves numeric-looking opaque identifiers and leading zeroes. Recovery removes the storage scalar layer, validates `I:`, and then enters the 50-digit amount path.

Recovery replays the append-only records into a fresh `AccountingBook`, verifies sequence/order, verifies the arithmetic profile, reconstructs balances and source-event indexes, and then reattaches the store for continued operation.

`examples/durable_jpy_book_demo.rex` demonstrates a 40-digit JPY posting surviving restart exactly.

## Company isolation and shared economic chains

A common correlation reference can connect separate companies without creating a common ledger:

```text
ECONOMIC-CHAIN-001
  FlyLo       -> FlyLo accounting event -> FlyLo journal
  Federation  -> Federation event       -> Federation journal
  All Japan   -> AJI event              -> AJI journal
  VMM         -> VMM event              -> VMM journal
```

Each side may legitimately use a different amount, timing, account classification, recognition basis and entity accounting policy.

`examples/four_company_transaction_demo.rex` demonstrates exactly this shape, including VMM-specific trust/encumbrance dimensions that remain local to VMM's accounting evidence.

## Exotic accounting structures stay in policy

Core journal lines accept open evidence-bearing dimensions. Company policies can therefore account for structures involving legal/beneficial ownership, trusts/SPVs, collateral, hypothecation/rehypothecation, reinsurance, derivative valuation, consolidation and future reporting regimes without modifying the double-entry engine.

The invariant remains:

> Accounting Core enforces posting mechanics and evidence binding; executable entity policy decides the accounting consequence of authoritative source evidence.

## Native posted accounting truth

`AccountingBook` provides:

- legal-entity and book identity
- chart-of-accounts validation
- open/closed/locked periods
- immutable journal entries
- per-currency double-entry balance
- source-event idempotency/conflict protection
- policy/source/correlation/evidence references
- exact integer minor-unit monetary amounts
- reversals rather than mutation/deletion
- trial balance
- correlation/event-type query helpers

A multi-currency journal may contain several currencies, but every currency must balance independently.

## External financial-statement assessment remains separate

`AccountingAssessmentBook` is separate from `AccountingBook`:

```text
AccountingEngine
  |-- book()         -> native posted accounting truth
  `-- assessments()  -> external evidence for assessment
```

Companies House/Civic imports never create GL journals implicitly.

v0.2's real WALKABOUT LTD filing qualification remains retained in v0.6: 89 iXBRL facts, taxonomy/context/dimensions, exact lexical/normalized values, reporting-framework evidence and filing completeness. The assessment policy verifies safe arithmetic relationships and explicitly preserves that the Income Statement was not delivered rather than treating missing data as zero.

See `docs/CIVIC_COMPANIES_HOUSE_ACCOUNTS_CONTRACT.md` and `docs/REAL_FILING_16024067_QUALIFICATION.md`.

## Supplied ecosystem baseline

The module is qualified against the supplied `oorexxapis(20260828-135139).zip` roll-up. Relevant reference components include CivicPort v0.12, Institutional Policy v0.8, Legal Effect v0.14, Runtime Registry v0.14 and Queue Fabric v0.9-dev4. Accounting Core deliberately has no runtime dependency on them yet; the interfaces are shaped so those components can provide transport, authority/evidence and artifact identities without moving their responsibilities into Accounting.

## Qualification

With ooRexx 5.3.0 available as `rexx`:

```bash
./run_tests.sh
```

The ooRexx suite covers core posting, transaction/policy dispatch, four-company isolation, Civic assessment and the real Companies House filing. If Python 3 is present, the real filing projection is also regenerated and checked byte-for-byte.
