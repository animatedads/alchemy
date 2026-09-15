# FederationBank Merchant Reference Adapter v0.8

Read-only evidence-preserving relation adapter for Merchant Banking instrument-resolution facts.

It exists to reuse the existing NoSQLServer + Structured Relation query machinery instead of building a second reference-data/query engine inside Merchant Banking.

`MBInstrumentResolutionEvidence` objects are projected into a queryable relation named `merchant_instrument_lines`. SQL sees scalar fields such as ISIN, venue MIC, denomination currency, settlement/security line and place of safekeeping. The rich row still retains the originating evidence object.

This package does **not** fetch the web, parse Citi documents, or assert that public reference data is current. Acquisition is a separate evidence-source responsibility. It consumes already-attributed evidence and preserves its provenance through queries.

The shipped regression models the Citi ISO 15022 multi-listed-security example:

- one ISIN may map to different listing lines;
- place of listing selects the market line;
- two London lines may additionally require denomination currency;
- place of safekeeping remains a separate operational discriminator.

The instrument relation is read-only. Query results cannot mutate source evidence.

v0.2 also projects the versioned `MBHedgeEquivalenceEvidence` stream through `merchant_hedge_equivalence`.  This exposes the complete healthy/impaired/restored history, strict supersession chain, Legal Effect/source references and the exact instrument-resolution evidence bound to each leg.  `is_current` is a derived query field; historical rows remain present and retain their originating rich ooRexx evidence object.

Both relations are read-only.


## v0.3 — hedge remediation projection

Adds the read-only `merchant_hedge_remediation` rich relation alongside
`merchant_instrument_lines` and `merchant_hedge_equivalence`.  Operations can
query open/escalated/resolved remediation obligations, due times, triggering
risk/equivalence evidence, action evidence and resolution/escalation provenance.
Each projected row retains the original `MBHedgeRemediationObligation` object.
The relation is read-only; SQL cannot clear or rewrite a remediation obligation.


## v0.4 — whole CFD hedge-book projection

Adds read-only `merchant_cfd_hedge_book` rich projection for v0.8 whole-book
assessments.  SQL can select aggregate directional residuals, impaired/unproved
hedge counts, remediation counts and counterparty/replacement exposure while
rich rows retain the original `MBCFDHedgeBookAssessment`, including exact trade
and hedge membership.  The projection is read-only.


## v0.6 — reconciled attestation and market-structure projections

Qualified against FederationBank Merchant Bank v0.11.  Adds two optional,
read-only rich relations:

- `merchant_instrument_attestations` over `MBInstrumentResolutionAttestation`;
- `merchant_market_structure_events` over `MBMarketStructureEvent`.

The scalar projections expose product/version/evidence/settlement-line and
market-structure availability/provenance fields for SQL selection.  The rich
rows retain the originating ooRexx evidence objects.  SQL remains unable to
attest a product, apply a market event to a hedge, or mutate either evidence
stream.


## v0.8 — remediation-plan projection

Adds `merchant_hedge_remediation_plans`, a read-only rich relation over v0.13 Merchant-domain plans. SQL can select current plan state, whole-book baseline, projected final exposure, peak transient exposure and maker/checker evidence while the originating `MBHedgeRemediationPlan` remains attached to the rich row.

The projection is observational only; query clients cannot approve or execute remediation.


### v0.8 execution-evidence and verification projections

The v0.8 adapter also exposes `merchant_hedge_remediation_plan_execution` and `merchant_hedge_remediation_plan_verifications`. The former projects attributable per-step observed execution evidence; the latter projects Merchant-domain comparison of that evidence with the approved plan and current whole-book result.

`merchant_hedge_remediation_plans` additionally exposes execution start/completion, verification identity/state, actual net base exposure and projection deviation. Every relation remains read-only and its rich rows retain the original Merchant-domain objects. Query clients cannot manufacture, alter or approve execution evidence or verification results.
