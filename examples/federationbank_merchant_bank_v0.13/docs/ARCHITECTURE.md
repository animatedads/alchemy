# Merchant Bank v0.13 architecture

## Four truths, not one `CLOSED` flag

For CFDs the implementation deliberately separates:

1. **contractual truth** — the promise remains active;
2. **client-view truth** — the UI may report the requested position closed;
3. **economic truth** — reversing legs can reduce/net directional exposure;
4. **risk truth** — FX, basis, counterparty, replacement, liquidity and legal-transfer risks may remain.

A CFD can therefore be:

```text
contractState     = ACTIVE
clientViewState   = CLOSED
economicState     = NET_ZERO
riskState         = RESIDUAL_RISK
monitoringRequired= true
```

without contradiction.

## Hedge identity

`economicUnderlyingId` is deliberately distinct from `ISIN`, venue and representation. This permits the risk book to represent:

- one legal security on multiple venues/currencies;
- related DLC securities in separate legal issuers;
- ordinary/depositary/CDI representations;
- legacy underlying-only hedges where richer identity is unavailable.

None of those relationships removes either contractual leg from monitoring.

## Sanctions / market-fragmentation event

A hedge relationship retains continuing assumptions for conversion, settlement, custody movement, legal transfer and liquidity. A new Legal Effect / market-access fact can invalidate an assumption without changing either derivative contract.

The resulting risk event is a hedge-equivalence impairment, not a trade-close event.

## Default

A Merchant default instruction is economically a risk-neutralisation requirement. For CFDs it is satisfied by attributable reversing contracts plus contractual difference calculation. Actual Core-held collateral realisation or cash movement remains across the regulatory perimeter.


## Evidence-bound instrument resolution

The Merchant Bank distinguishes economic identity from operational settlement identity.  `MBReferenceDocumentEvidence` records the source document and observation provenance.  `MBInstrumentResolutionEvidence` records a source-supported resolution of economic underlying + ISIN + venue + denomination + settlement/security line + safekeeping/custody context.  `MBInstrumentIdentity` may bind itself to that evidence.

Product registration validates evidence-bound identities.  A source answer therefore cannot be flattened into a ticker/ISIN and later acquire stronger identity merely because it was stored in the product catalogue.


## Versioned equivalence state (v0.6)

Market/economic linkage and legal/operational fungibility are separate facts.
For non-exact offsets, the current hedge equivalence is supported by an immutable
`MBHedgeEquivalenceEvidence` chain.  The chain is monotonic by version and explicit
`supersedesEvidenceRef`; history is not rewritten when sanctions or custody
conditions change and is not rewritten again when restrictions are lifted.

Equivalence evidence may be bound to each leg's exact instrument-resolution
evidence.  This prevents a legal/market-structure observation for one security
line from being silently applied to another representation or denomination.

`reassessHedgeRiskFromLatestKnown` allows a legal/operational equivalence event to produce a fresh risk assessment using the last known FX, basis and counterparty evidence (falling back to sizing FX where necessary).  This makes the absence of a new price tick explicit rather than blocking the recognition of a sanctions/custody event.


## Hedge remediation obligations (v0.7)

Equivalence impairment creates an operational risk problem distinct from the
underlying contractual lifecycle.  Merchant Risk may open a durable remediation
obligation bound to the exact impairment assessment/evidence version.  Actions
are evidence, not state-flip commands.  Restoration requires a current
post-action assessment against current equivalence evidence.

Replacement/transfer evidence is intentionally insufficient on its own: whole
book proof is required before an impaired hedge can be considered mitigated or
resolved, preventing replacement activity from accidentally doubling exposure.
The original contracts remain live and monitored.


## Whole CFD hedge book (v0.8)

Risk remediation is proved over the contractual hedge graph, not an isolated
pair.  Starting from the client CFD, the graph includes each reversing contract
and any reversal of those reversing contracts.  Aggregate exposure must be
recomputed before replacement activity can be considered mitigating.

A replacement which simply adds another short against a client long is rejected
as directional residual.  Neutralising the old short and then adding the new
short can restore aggregate net-zero direction, but the old impaired hedge
remains a monitored contractual/legal risk until its own equivalence is restored
or its contract is otherwise legally transferred/terminated.


## Reconciled v0.9 evidence authorities

v0.9 preserves the v0.8 whole-book/remediation model and restores three
explicit authority/evidence seams from the parallel implementation branch:

1. product instrument-resolution attestation over the exact versioned product,
   evidence record and settlement-line key;
2. settlement-line identity as a hedge relationship distinct from exact CFD
   contract identity; and
3. first-class market-structure events whose exact instrument-line scope is
   checked before they can advance hedge-equivalence evidence.

These are complementary layers.  An attestation proves what line a product was
governed against; a settlement-line hedge states the relationship between two
contracts; a market-structure event records a later change in the legal or
operational assumptions supporting that relationship.  None deletes contracts
or bypasses aggregate hedge-book proof.


## Remediation execution evidence (v0.13)

The planning authority and the execution authorities remain separate. An approved `MBHedgeRemediationPlan` states the intended ordered actions and projected exposure path; it does not execute them. Owning authorities later produce attributable `MBHedgeRemediationPlanStepExecutionEvidence`.

The Merchant domain deliberately records adverse evidence too. A wrong-way trade, partial execution or failed step is an observed fact and must not disappear because it makes the approved plan look bad. Verification therefore happens after evidence capture and compares:

1. approved step order and semantics;
2. actual Merchant objects referenced by the execution evidence;
3. observed signed exposure deltas;
4. the evidence-implied net book; and
5. a current customer-rooted `MBCFDHedgeBookAssessment`.

A superseded assessment is not proof. `VERIFIED` means the actual resulting book matched the approved projection; `DEVIATED` preserves the mismatch. Neither result alters the contractual remediation obligation by itself.
