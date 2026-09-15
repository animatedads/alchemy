# Changelog

## 0.10 - 2026-09-01

Regulatory filing lifecycle release.

- adds `accounting.reporting.filing/0.1` and `accounting.reporting.lifecycle/0.1`
- adds immutable `AccountingReportingFilingVersion` for `ORIGINAL`, `AMENDMENT` and `CORRECTION` lineage
- binds each filing to exact snapshot/boundary and exact attestation-set identities
- amendments/corrections retain the exact predecessor filing ID/fingerprint and a reason reference
- adds append-only `SUBMITTED`, `RESUBMITTED`, `ACKNOWLEDGED`, `ACCEPTED`, `REJECTED`, `WITHDRAWN` and `SUPERSEDED` lifecycle observations
- every lifecycle event binds the exact immediately prior event fingerprint, actor, asserted authority ref/identity and applicable submission/external evidence
- regulator acknowledgement/decision events require exact external evidence identity
- resubmission binds an exact earlier submission-event fingerprint; supersession binds an exact successor filing fingerprint
- superseded filings become immutable historical workflow evidence and cannot receive new lifecycle events
- proves stale/rejected original -> corrected/superseded -> resubmitted/accepted flow without rewriting historical accounting, attestation or receipt evidence
- rebases the optional SHA-256/Ed25519 reporting adapter from Crypto v0.5 to roll-up Crypto v0.8.3 with unchanged adapter contract
- retains all v0.9 attestation/submission, v0.8 sealed reporting, v0.7 settlement, v0.6 tax, v0.5 scopes and earlier accounting contracts

## 0.9 - 2026-08-28

Regulated-report attestation/submission evidence release.

- adds `accounting.reporting.attestation/0.1` and `accounting.reporting.submission/0.1`
- binds attestations to exact snapshot and boundary fingerprints
- includes attestor, semantic authority ref, immutable authority identity, purpose, occurrence time, proof algorithm and exact key identity in the signed/sealed payload
- keeps authority validity outside Accounting Core while making claimed authority cryptographically non-substitutable
- adds algorithm-neutral proof-provider/verifier boundary and explicit structural/cryptographic verification results
- adds optional Crypto v0.5 SHA-256 + Ed25519 reporting adapter with exact key-identity checks
- adds submission/receipt evidence binding the exact snapshot and exact attestation set to external submission/receipt identities
- proves later/backdated accounting can stale a historical report without destroying evidence of what was actually approved and filed
- retains all v0.8 reporting snapshot, v0.7 settlement, v0.6 tax, v0.5 scope, v0.4 persistence/precision, transaction and Civic/Companies House contracts

## 0.8 - 2026-08-28

Sealed evidential reporting release.

- retains live `accounting.reporting/0.1` and adds additive `accounting.reporting.snapshot/0.1`
- adds immutable reporting-line entry/line fingerprints and deterministic projections
- seals exact boundary/policy identity, selected lines and complete ordered source-book journal cutoffs
- adds `AccountingReportingService~sealSnapshot()` and `verifySnapshot()`
- distinguishes `VALID`, `VALID_SOURCE_ADVANCED` and `REPORT_POPULATION_STALE`
- rejects changed historical entry fingerprints, missing/truncated source books, substituted boundary identity and changed in-boundary source-book sets
- adds generic currency-safe `totalsByDimensions()` for client-money, establishment, tax, regulatory, matter and company-specific dimensions
- proves a holistic report can span multiple legal entities while retaining each line's exact legal-entity/book identity; reporting is not consolidation by fiat
- keeps all v0.7 settlement, v0.6 tax, v0.5 scope, v0.4 precision/persistence, transaction and Civic/Companies House contracts unchanged

## 0.7 - 2026-08-28

Settlement-rounding separation release.

- adds `accounting.settlement/0.1`, `accounting.settlement.request/0.1` and `accounting.settlement.determination/0.1`
- adds effective-dated `AccountingSettlementRoundingElection` with legal entity, jurisdiction, currency, exact ruleset identity, rounding algorithm reference, integer-minor-unit quantum and explicit tender classes
- does not infer that settlement rounding is cash-only; `*`, physical-cash-only and other explicit tender scopes are supported
- allows overlapping date ranges only where tender scopes are disjoint; overlapping tender applicability is rejected
- adds external exact-ruleset `AccountingSettlementPolicy` dispatch and locks executable policy/election identities in every determination
- adds `AccountingSettlementMath~roundToQuantum()` under `DIGITS 50`
- adds neutral `HALF_EVEN` rounding support while leaving jurisdictional applicability to external policy
- adds settlement request/determination projections with deterministic fingerprints
- adds `determineSettlement()`, `determineSettlementProjection()`, `transactSettlement()` and `transactSettlementProjection()`
- converts settlement determinations into ordinary accounting events; company accounting policy decides gain/loss/account classification
- settlement rounding does not alter tax determination or tax amounts already recognized
- adds restart-safe settlement replay: exact replay is `DUPLICATE`; changed reuse is `SOURCE_SETTLEMENT_EVENT_CONFLICT` before settlement/accounting policy dispatch
- qualifies an all-tender SEK whole-krona shape and a physical-cash-only five-cent shape without hard-coding either jurisdictional rule into Accounting Core
- retains all v0.6 tax, v0.5 scope/reporting, v0.4 precision/persistence, transaction and Civic/Companies House guarantees


## 0.6 - 2026-08-28

Generic tax-determination contract release.

- adds `accounting.tax/0.1`, `accounting.tax.request/0.1` and `accounting.tax.determination/0.1`
- adds signed exact-rational `AccountingTaxExactAmount` arithmetic under the existing 50-digit precision contract; no binary floating-point tax calculation
- adds reusable jurisdiction-neutral quantization and `HALF_UP` / `TRUNCATE` / `FLOOR` / `CEILING` mechanics while leaving the legal meaning/timing of rounding to jurisdiction policy
- adds transportable tax-request and tax-determination projections with deterministic fingerprints
- dispatches tax policy by the exact `rulesetIdentity` selected by the effective `AccountingTaxElection`, not by company domicile or mutable country defaults
- requires tax policy packages to compile with `::OPTIONS DIGITS 50` and locks exact `taxPolicyIdentity` in every accepted determination
- validates determination binding to source tax event, legal entity, tax point, currency, basis, registration, election, ruleset, executable policy, correlation and counterparty
- adds `AccountingEngine~determineTax()`, `determineTaxProjection()`, `transactTax()` and `transactTaxProjection()`
- converts accepted determinations into ordinary `AccountingEvent` evidence; entity accounting policy still owns GL account selection and posting treatment
- adds durable tax replay: once posted, same request returns `DUPLICATE` before tax/accounting policy dispatch and changed reuse becomes `SOURCE_TAX_EVENT_CONFLICT` even after restart
- qualifies a foreign/non-established UK VAT registration and an Australian GST registration through the same generic core
- qualifies signed credit-note tax determinations and accounting-side debit/credit reversal
- retains all v0.5 scopes/reporting, v0.4 precision/persistence, event/policy and Civic/Companies House guarantees

## 0.5 - 2026-08-28

Orthogonal statutory-scope and reporting-boundary release.

- adds `accounting.scope/0.1` and standard journal dimension identities for establishment, tax registration, tax election, regulatory registration, client-money arrangement, matter and relationship kind
- adds independent `AccountingEstablishment`, `AccountingTaxRegistration`, `AccountingTaxElection`, `AccountingRegulatoryRegistration` and `AccountingClientMoneyArrangement` objects
- permits a foreign legal entity to hold a UK VAT registration without creating a fictional UK legal entity or UK establishment
- separates stable tax registration from effective-dated tax election; election freezes exact ruleset identity, rounding algorithm, calculation granularity and return scheme
- rejects overlapping tax elections for one registration and requires the exact active election identity on tax-tagged postings once an election is configured
- validates establishment/tax/regulatory/client-money references, effective dates, client-money currency and relationship-kind semantics before `AccountingEngine` posting
- adds `accounting.reporting/0.1`, immutable `AccountingReportingBoundary`, `AccountingReportingService` and reporting views/totals over one or more native books
- distinguishes `INTER_ESTABLISHMENT` from `INTERCOMPANY` rather than inferring legal entities from places of business
- adds a dual-jurisdiction law-firm qualification: UK VAT, Australian GST, SRA-style and Australian regulatory registrations plus GBP/AUD client-money arrangements in one legal-entity book
- proves reporting boundaries can derive jurisdictional tax views and a holistic multi-currency Client Account view from the same immutable journals
- proves standard scope/tax-election/matter dimensions survive append-only store recovery byte-exactly and remain reportable after restart
- retains all v0.4.1 DIGITS 50, persistence, event/policy, Civic and Companies House guarantees

## 0.4.1 - 2026-08-28

Sibling-branch reconciliation release.

- reconciles the independently supplied `accounting_core_v0.3.1` repair into the v0.4 lineage
- confirms v0.4 already executes `requireWholeNonNegative` under `numeric digits 50` before `DATATYPE(..., "W")`
- restores the explicit 12,000,000,000 exact-minor-unit transaction regression from v0.3.1
- retains v0.4's stronger 40-digit JPY, 51-digit rejection, durable-book, period-lifecycle, Civic and Companies House guarantees unchanged
- no API generation, recognition, measurement, policy-dispatch, posting or assessment semantics changed

## 0.4 - 2026-08-28

- Makes `NUMERIC DIGITS 50` an explicit accounting arithmetic contract.
- Adds `::OPTIONS DIGITS 50` to Accounting Core source packages.
- Rejects executable accounting-policy packages compiled below 50 digits.
- Keeps minor-unit amounts as exact canonical integer strings and rejects values wider than 50 significant digits instead of rounding.
- Adds `accounting.store/0.1` and `AccountingFileStore`, an append-only JSONL durable-book implementation.
- Persists book/arithmetic identity, chart mutations, accounting periods, period transitions and immutable journals.
- Uses prefixed `I:<integer>` strings for persisted money so JSON serializers cannot reclassify large monetary strings as numbers.
- Recovers balances, deterministic journal identities, source-event fingerprints and period lifecycle across restart.
- Adds actor/reason/evidence/time-bearing period transition history and durable close/lock semantics.
- Adds restart-safe preferred transaction qualification: exact event replay returns the original journal before policy dispatch even when the recovered engine has no policy registered.
- Adds large-JPY qualification using 40-digit minor-unit amounts and a 51-digit rejection probe.
- Retains all v0.3 transaction, four-company, Civic and real Companies House qualification.


## 0.3.1 - 2026-08-28

Institutional-scale exact minor-unit compatibility repair (sibling branch, now reconciled).

- executes `requireWholeNonNegative` under `numeric digits 50` before `DATATYPE(..., "W")`
- adds a transaction-path regression for 12,000,000,000 exact minor units
- retains `accounting.event/0.1`, `accounting.transaction/0.1`, and `accounting.posting/0.2` unchanged

## 0.3 - 2026-08-28

Operational accounting event and executable-policy path.

- added `accounting.event/0.1` normalized event contract and `AccountingEventCodec`
- added `accounting.transaction/0.1` preferred `AccountingEngine~transact()` / `transactProjection()` path
- added exact legal-entity, event-type and effective-date accounting-policy resolution
- added immutable `policyIdentity` alongside semantic `policyRef` and retained both on posted journals
- reject overlapping policy effective ranges for the same legal entity/event type
- source-event replay/conflict check now occurs before policy execution, preventing historical replay through newer policy
- bind accepted policy drafts to source fingerprint, correlation, policy identity, counterparty, source authority and evidence refs
- recursively detach nested Directory/Array payload, metadata and dimensions from caller mutation
- convert policy execution syntax failures into bounded `POLICY_EXECUTION_FAILED` transaction results
- added correlation/event-type journal queries
- enforced configured currency for `SINGLE`-currency accounts
- added formal four-company isolation/correlation qualification for FlyLo, Federation distribution, All Japan and VMM
- added four-company transaction demo including trust/rehypothecation dimensions local to VMM
- retained v0.2 Companies House/Civic assessment boundary and real WALKABOUT LTD qualification unchanged

## 0.2 - 2026-08-28

Real Companies House assessment integration.

- kept native core/posting APIs at 0.1; advanced assessment API to `accounting.assessment/0.2`
- advanced Civic normalized import adapter to `accounting.civic.companieshouse/0.2` while retaining v0.1 source-contract compatibility
- added fact-level provenance: source QName/context/unit/format/decimals/scale, exact normalized value and duplicate evidence
- added taxonomy-reference and filing-completeness retention
- added canonical concept namespace/local-name query helpers
- added recursive canonicalization so nested external evidence participates in idempotency/conflict fingerprints
- added `AccountingCompaniesHouseAssessment` policy/plugin with evidence-safe arithmetic and disclosure checks
- added real WALKABOUT LTD / Companies House 16024067 iXBRL qualification fixture
- added deterministic reference Civic iXBRL projection tool; no production Accounting dependency on Python/XBRL
- locked the rule that a filed-accounts import never posts to native GL
- locked `not filed != zero` semantics for intentionally omitted Income Statements

## 0.1 - 2026-08-28

Initial reusable accounting core.

- independent legal-entity accounting books
- chart of accounts and accounting periods
- balanced immutable journal posting with per-currency balance enforcement
- source-event idempotency/conflict detection
- reversals and trial balance
- open dimensions/evidence model for unusual legal/economic structures
- separate external financial-statement assessment book
- forward-compatible Civic Companies House accounts normalized-import contract
