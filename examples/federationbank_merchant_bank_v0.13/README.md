# FederationBank Merchant Bank v0.13

A deliberately separate Merchant Banking / capital-markets authority for Federation Bank Australia IOM.

## Regulatory perimeter

Merchant Banking remains **at arm's length from FederationBank Retail/Core Banking**. It owns derivative contractual state, product governance, valuation, exposure/risk, margin/default, hedge/offset state and Merchant contractual settlement obligations.

It does **not** own Retail/Core account balances, Retail Ledger postings, Core asset ownership, Core encumbrance validity/priority, or actual Core cash movement.

Core-held collateral contributes zero Merchant margin value until Core Banking has explicitly acknowledged enforceable control under the separate collateral protocol.

## v0.4 correction: a CFD "close" is an offset intent

A front-end `CLOSE POSITION` does not destroy a CFD contract. It requests a reversing economic position.

```text
client CLOSE intent
      |
      v
validate required opposite direction
      |
      v
book reversing CFD contract
      |
      v
recalculate exposure
      |
      +-- exposure did not fall --> REJECT / ALERT
      |
      +-- net exposure reduced --> hedge relationship retained
```

The original and reversing CFD contracts both remain `ACTIVE` and under risk monitoring. The client view may become `CLOSED` when the intended economic exposure reaches zero.

The implementation therefore keeps separate facts for:

- contractual state;
- client-view state;
- economic/risk state.

`MBDerivativeTrade~close` now rejects CFDs. Legal termination remains available for genuine option exercise/expiry/termination lifecycle events.

## Wrong-way close protection

A requested close of a short CFD must not execute another short; a requested close of a long must not execute another long.

`bookCFDOffset` validates that the reversal direction is opposite and that absolute net exposure falls before the reversing trade is admitted to the book.

Named regression: `test_cfd_wrong_way_close.rex`.

## Instrument identity and hedge classes

Ticker and even ISIN alone are insufficient risk identity.

`MBInstrumentIdentity` retains:

- economic underlying identity;
- ISIN/legal instrument reference;
- venue MIC;
- representation type;
- quote currency;
- settlement currency;
- contract currency;
- conversion ratio;
- issuer/depositary reference.

The Merchant book distinguishes:

- `EXACT_OFFSET`;
- `CROSS_LISTED_HEDGE`;
- `DLC_EQUIVALENCE`;
- `DEPOSITARY_HEDGE`;
- `UNDERLYING_HEDGE`.

Two legs can therefore share an economic underlying, or even an ISIN, without being treated as the same risk contract.

## Cross-listed FX drift

A cross-currency hedge is sized using attributable `MBFXEvidence`. The sizing FX evidence is retained on the hedge relationship.

Later FX evidence can reopen translated exposure even if the two legs were value-matched at the instant of offset.

```text
at offset time:
    GBP leg + translated EUR leg ~= 0

later FX rate:
    same live contracts
    translated net exposure != 0
```

The resulting `MBHedgeRiskAssessment` exposes directional exposure and FX-translation drift rather than continuing to call the position risk-free.

## Imported CFD / counterparty risk

An imported hedge leg is a separate live contract with an external counterparty. `MBCounterpartyRiskEvidence` retains current counterparty exposure and replacement cost.

A hedge may therefore report:

```text
directional market exposure = 0
counterparty exposure        > 0
replacement cost             > 0
```

and remains `RESIDUAL_RISK` and monitored.

## Fungibility, sanctions and illiquidity

Economic equivalence is conditional on continued legal and operational fungibility.

`MBHedgeFungibilityEvidence` records whether conversion, settlement, custody transfer, legal transfer and market liquidity remain available, with attributable Legal Effect and source authority evidence.

If a jurisdiction-specific restriction breaks one of those assumptions, the hedge becomes `IMPAIRED` even if the pre-event economics were equivalent.

`MBBasisRiskEvidence` can retain the resulting illiquidity/basis dislocation separately from FX and counterparty risk.

The risk layer therefore covers the case where:

```text
X ~= Y before restriction
X != Y after restriction
```

because one representation becomes non-transferable, non-deliverable, illiquid or legally restricted.

## Gross contractual exposure vs risk exposure

CFD promises can remain legally live after economic netting, so gross contract population is not the same thing as current risk exposure.

`MBValuationSnapshot` now carries both:

- `grossExposure` — live contractual/gross exposure evidence;
- `riskExposure` — the risk amount used by margin/leverage policy.

Existing callers that do not supply `riskExposure` retain v0.3 behaviour because it defaults to `grossExposure`.

## Default: risk neutralisation, not CFD deletion

The v0.3 default instruction remains compatible, but a portfolio containing CFDs must use `executeRiskNeutralisation` rather than the legacy legal-lifecycle `executeCloseOut` method.

`executeRiskNeutralisation` requires one `MBCFDNeutralisationResult` for every exposed CFD selected for the default action and validates the full set before booking any reversal.

Each original CFD remains active. Reversing contracts are booked and retained. The realised difference becomes an `UNSETTLED` Merchant contractual obligation; no Core account or Ledger mutation occurs here.

## Client position summary

The ATM/read-only Merchant position projection now counts client economic positions separately from monitored live contracts. A CFD whose client view is closed can disappear from the customer's open-position count while both contractual legs remain in the Merchant risk universe.

## Collateral and settlement boundaries

The existing Merchant collateral-control and cash-settlement protocols remain unchanged. Core Banking continues to decide actual ownership, enforceability, priority and money movement.

## Journal

State-changing Merchant facts continue to be recorded through Journal Pointed State. This journal supports live history/recovery experiments and does not replace whole-machine freeze/checkpoint evidence.

## Validation

Run:

```bash
JOURNAL_POINTED_STATE_HOME=/path/to/oorexx_journal_pointed_state_v0.1 \
REXX=/path/to/rexx ./run_tests.sh
```

Validated under ooRexx 5.3.0 r13196.


## v0.5 — evidence-bound instrument and settlement-line identity

v0.5 separates **economic instrument identity** from the operational settlement line used to trade, settle and custody that instrument.  An instrument identity may now retain:

- ISIN;
- place of listing / venue MIC;
- denomination currency (distinct from quote/contract currency);
- settlement/security-line reference such as the selected SEDOL line;
- place of safekeeping / custody route;
- the exact reference-evidence record that justified the resolution.

Reference documents and individual instrument-resolution facts are journalled evidence.  A product that names resolution evidence is rejected unless its instrument identity matches that evidence.  This prevents a query result from being flattened to a ticker or ISIN and later acquiring stronger identity than the source actually supported.

The regression fixture is based on Citi's *ISO 15022 Settlement Instruction Requirements for Multi-Listed Securities (SR2014)*: place of listing selects a multi-listed ISIN line; where two London lines exist, denomination currency is additionally required; place of safekeeping may distinguish otherwise related holdings.


## v0.6 — versioned hedge-equivalence evidence

Hedge equivalence is no longer a timeless attribute.  A cross-listed, DLC,
depositary or underlying hedge may have one evidence state at 09:00 and a
different state after a sanctions, custody, settlement or market-liquidity
event.

`MBHedgeEquivalenceEvidence` is an immutable evidence stream per hedge.  Version
1 establishes the first observation.  Every later observation must advance the
version exactly once and explicitly identify the evidence record it supersedes.
The old evidence remains queryable and journalled.

Where the derivative products are backed by `MBInstrumentResolutionEvidence`,
equivalence evidence must cite the exact resolution evidence for both the
original and reversing legs.  Sharing a ticker, ISIN, issuer or economic
underlying is not enough to apply a market-structure observation to another
settlement line.

A new impaired observation immediately changes the hedge's current equivalence
and economic monitoring state to `HEDGE_IMPAIRED`; it does not require a new
price tick to make a legal/operational loss of fungibility real.  A later risk
assessment records the exact equivalence-evidence version it consumed.

Example history:

```text
09:00  EQE-1 v1  EQUIVALENT   conversion/settlement/custody available
11:17  EQE-2 v2  IMPAIRED     supersedes EQE-1; transfer restriction
14:30  EQE-3 v3  EQUIVALENT   supersedes EQE-2; fungibility restored
```

The 11:17 evidence is never rewritten to say that the hedge was always healthy.
The restoration is a new fact.  Contracts remain live and monitored throughout.

`reassessHedgeRiskFromLatestKnown` allows a legal/operational equivalence event to produce a fresh risk assessment using the last known FX, basis and counterparty evidence (falling back to sizing FX where necessary).  This makes the absence of a new price tick explicit rather than blocking the recognition of a sanctions/custody event.


## v0.7 — durable hedge surveillance and remediation obligations

A hedge-equivalence impairment is no longer complete merely because the risk
engine has labelled the hedge `HEDGE_IMPAIRED`.  Merchant Risk can open a
first-class `MBHedgeRemediationObligation` bound to the exact triggering hedge
risk assessment and equivalence-evidence version.

The obligation retains its policy reference, open time, optional due time,
action evidence, escalation evidence and eventual proof assessment.

Remediation action evidence is attributable and distinguishes:

- restored fungibility;
- custody re-homing;
- replacement hedge;
- hedge transfer;
- risk reduction.

Recording an action does **not** itself clear the obligation.  Restoration or
custody re-homing may resolve only when the latest hedge-risk assessment binds
the current healthy equivalence evidence.  A stale assessment is rejected.

Replacement/transfer evidence is retained but deliberately cannot yet resolve
the obligation: a single healthy replacement pair is not proof that the
aggregate book was not doubled.  That path is blocked pending whole-book
exposure proof.  Likewise risk reduction alone cannot erase an impaired
contractual hedge.

Escalation is explicit and policy-authorised; the domain does not infer that a
string timestamp has expired and silently default a remediation.

The original and reversing CFD contracts remain active and monitored after
remediation.


## v0.8 — whole CFD hedge-book proof

Replacement hedges are no longer evaluated only as isolated pairs.
`assessCFDHedgeBook` starts at the original client CFD and follows the complete
reversal graph: every hedge offset and every reversal of an offset.  It then
recomputes aggregate directional exposure in the root contract currency, using
the latest attributable FX evidence for cross-currency legs, while retaining
latest counterparty/replacement-cost evidence.

The assessment reports contract/hedge counts, gross and net base exposure,
impaired/unproved hedge counts, open remediation count and counterparty risk.
It never reports a generic risk-free state; even a fully netted graph remains
`NET_ZERO_WITH_MONITORING` or a more specific residual-risk state.

This catches the historical wrong-way replacement class directly: a client long
+ an old short hedge + another replacement short is aggregate short, despite
the replacement pair looking healthy by itself.

A replacement/transfer remediation can become `MITIGATED_MONITORING` only when
a current whole-book assessment includes the replacement hedge, proves aggregate
directional net zero, has no unproved hedge relationships and has no unexpected
additional impaired hedges.  Mitigation does not change the old contract's
legal/equivalence state.  Genuine resolution still requires restored current
equivalence evidence.


## v0.9 — reconciled instrument/market-structure lineage

v0.9 reconciles the independently-developed Merchant Banking branches without
discarding either line.  It retains the v0.8 hedge-remediation and whole-book
CFD reversal graph, while restoring the explicit product-resolution and
market-structure APIs from the parallel lineage.

### Product instrument-resolution attestation

`MBInstrumentResolutionAttestation` and
`attestProductInstrumentResolution` provide an explicit attestation that a
versioned derivative product is bound to the exact instrument-resolution
evidence and settlement line claimed by its `MBInstrumentIdentity`.  An
attestation is rejected when the product version, resolution evidence or
settlement-line key does not match, or when the product was never evidence
bound.

This is deliberately stronger than saying that a product merely *contains* an
ISIN.  It gives product governance an attributable assertion over the exact
venue / denomination / security-line / safekeeping resolution that was used.

### Settlement-line hedge identity

`MBInstrumentIdentity~sameSettlementLineIdentity()` and the explicit
`SETTLEMENT_LINE_HEDGE` relationship distinguish a shared operational
settlement line from exact derivative-contract identity.  Two CFD contracts can
therefore refer to the same underlying settlement line while differing in their
derivative contract currency.  They are related hedges, not silently collapsed
into one contract.  Different denomination currencies, security-line refs or
places of safekeeping remain distinct.

### First-class market-structure events

`MBMarketStructureEvent`, `recordMarketStructureEvent` and
`applyMarketStructureEventToHedge` make sanctions, custody, settlement,
transferability and liquidity changes explicit events rather than ad-hoc flags.
An event is bound to an exact instrument-resolution evidence record and may be
applied only to a hedge whose original or offset leg uses that record.

Applying an event creates the next immutable `MBHedgeEquivalenceEvidence`
version and preserves event -> hedge -> evidence provenance.  A restrictive
event can therefore impair a hedge immediately without a new price tick, while
the v0.8 remediation and whole-book controls remain in force.

### Reconciliation invariant

The merge is accepted only when both lineages remain executable:

- explicit instrument attestation / settlement-line identity / market-structure
  event semantics from the parallel line; and
- versioned equivalence, remediation obligations, aggregate CFD hedge-book
  proof, wrong-way replacement rejection and mitigated-monitoring semantics from
  the v0.8 line.

No Retail/Core Banking implementation is introduced by this reconciliation.


## v0.11 — customer-rooted hedge-book discovery

- Adds read-only `rootCFDTradeIdForHedge(hedgeId)` to resolve a nested reversing/hedging leg back to the original customer-rooted CFD contract.
- Adds read-only `rootsAffectedByInstrumentEvidence(evidenceRef)` to deduplicate affected customer-rooted books after exact settlement-line discovery.
- Root discovery walks only existing Merchant-owned hedge relationships and rejects cycles/ambiguous ancestry rather than guessing.
- No trade, valuation, collateral, settlement or Core Banking authority is added.

## v0.10 — surveillance discovery boundary

Operational Merchant Risk services can enumerate hedge identifiers and ask the Merchant domain which hedges reference an exact `MBInstrumentResolutionEvidence` record.  This is deliberately a read-only discovery surface; callers do not receive the private trade/product tables and cannot infer affected legs from ticker or ISIN alone.


## v0.12 — governed remediation execution planning

A remediation obligation may now acquire an ordered `MBHedgeRemediationPlan`. The plan is not an execution instruction and does not create a trade. It is bound to a current `MBCFDHedgeBookAssessment` and records the intended exposure effect of each step.

For a directionally netted book, a replacement plan must remain net zero. A blind second hedge is rejected before it becomes an approved plan. A correct replacement sequence can explicitly show the temporary exposure created while the impaired hedge is neutralised and the new hedge is added.

Approval is independent maker/checker evidence. Any newer whole-book assessment invalidates the approval baseline and requires a fresh plan or re-proposal. The Merchant Bank still requires actual post-action evidence and fresh whole-book/risk proof before remediation can later be mitigated or resolved.


## v0.13 — attributable remediation execution evidence

An approved remediation plan remains a projection until the owning execution authorities act. v0.13 records those observed outcomes as `MBHedgeRemediationPlanStepExecutionEvidence`; it does not let Merchant Risk turn an approved plan directly into a trade.

Execution evidence names the exact approved plan step, authenticated/source authority references, actual resulting Merchant object where applicable, observed signed base-exposure delta, effective time and policy evidence. A wrong-way fill is retained as an attributable fact rather than rejected simply because it contradicts the plan.

`verifyHedgeRemediationPlanExecution` then compares the complete evidence set with both the approved ordered plan and a **current** customer-rooted CFD hedge-book assessment. It detects failed/partial/not-executed steps, order deviation, wrong actual-object semantics, signed-delta deviation, evidence/book mismatch and deviation from the approved projected final exposure. A stale/superseded book assessment cannot be used as proof.

Successful verification moves the plan to `VERIFIED`; disagreement moves it to `DEVIATED`. Neither state itself cures, mitigates or resolves the underlying `MBHedgeRemediationObligation`. Contractual remediation remains separately governed by current equivalence/risk/whole-book proof.
