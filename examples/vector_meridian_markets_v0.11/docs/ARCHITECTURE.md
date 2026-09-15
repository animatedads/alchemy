# Vector Meridian Markets v0.11 architecture

## Legal perimeter

```text
FederationBank Core/Retail
        |
        | explicit arm's-length loan/facility only
        v
Vector Meridian Markets Ltd

FederationBank Merchant Bank
        |
        | durable anonymised RFQ / execute messages
        v
   Queue Fabric boundary
        |
        v
Vector Meridian Markets Ltd
        |
        | VMM-owned smart route/risk/borrow/capital decision
        v
  Smart execution service
        |
        +--> durable route queue A --> adapter A --> venue/access channel
        +--> durable route queue B --> adapter B --> venue/access channel
        +--> durable route queue N --> adapter N --> venue/access channel
        |
        <--------- shared durable execution event queue ---------
```

There is no shared customer balance, customer-identity channel, principal book or inherited authority across these arrows.

## Direct institutional synthetic perimeter

```text
All Japan Insurance / other direct institution
        |  vmm.institutional.synthetic/0.5
        v
VMM institutional synthetic dealer / product books
        |  VMM contract ref only
        v
VMM smart execution / venue adapters
```

This is separate from Federation Merchant's anonymised RFQ path. A direct OTC institution is a disclosed VMM counterparty for KYC/contract/collateral purposes, but Federation receives no ACL or product-service reference. Raw portfolio positions remain inside VMM's institutional-product perimeter and are not copied into execution commands.

Post-trade client instructions use a second queue boundary, `vmm.institutional.synthetic.lifecycle/0.6`, for premium-payment notices and client-requested reference changes. The lifecycle gateway remains queue-only. VMM performs its own risk/accounting admission before any notice becomes VMM truth. Novation is deliberately tripartite and is not reduced to a one-sided lifecycle message.

## Synthetic lifecycle books

The synthetic desk keeps contractual payoff value, premium/collateral cash, and VMM risk-accounting evidence as separate books. Premium accrual/settlement and initial/variation margin do not rewrite contractual liability. CVA/FVA and hedge-effectiveness assessments are VMM evidence layers and likewise cannot change the client's payoff function.

Reference portfolio changes create immutable successor snapshots and lineage records. Client substitutions are subject to a configured value-drift cap plus current wrong-way-risk checks; corporate actions may alter value more substantially but still require evidence and VMM risk approval. Novation closes the old legal contract as `NOVATED` and creates a distinct incoming-counterparty contract under that counterparty's own master/collateral agreements.



## Default and close-out perimeter

Direct institutional default handling remains `vmm.institutional.synthetic.default/0.8`. Default notice, cure, uncured assessment, termination and original close-out determination are distinct immutable facts. Federation has no ACL on this boundary.

Post-determination operations use a separate `vmm.institutional.synthetic.closeout/0.9` Queue Fabric perimeter. A valuation dispute creates a new dispute object; independent fallback resolution creates another object; explicit finalization then becomes cash-settlement and accounting authority. The original v0.8 determination is never edited.

Only evidenced cash variation margin is included by the determination/finalization formula. Segregated IM remains separate and follows an exact-transfer custodian return lifecycle after cash close-out. VMM hedge unwind attribution remains internal economic evidence and cannot rewrite the legal close-out amount.

Master-agreement netting is legal set-off, not portfolio optimization. Membership requires the same counterparty identity, master agreement and currency plus explicit governing-law, legal-opinion and close-out-netting-election evidence. The netting determination preserves gross receivables/payables and authorizes one net cash settlement. A member cannot settle individually after joining the set.

## Accounting transaction perimeter

VMM uses `vmm.accounting/0.11` over Accounting Core `accounting.event/0.1` / `accounting.transaction/0.1`, with `accounting.store/0.1` for durable VMM accounting books and `accounting.scope/0.1` / `accounting.reporting/0.1` for evidence-bound projections. Operational/legal facts become immutable AccountingEvents; effective-dated VMM policy proposes the journal; Accounting Core enforces legal entity, replay, evidence/policy identity binding and posting mechanics. Accounting does not call back into VMM to change the source fact.

For v0.9 close-outs, finalization is the normal recognition point. Separate policies record finalized gross/net legal exposure, later direct settlement, legally evidenced master-netting-set settlement, and segregated-IM custody return at gross carrying value.

Accounting Core v0.7 retains 50-digit arithmetic as policy compatibility. VMM policy code compiles with `::OPTIONS DIGITS 50`. `VMMAccountingStore` can create/recover only the VMM statutory book and preserves chart, period lifecycle, journals, source fingerprints and policy identities across restart. This durable accounting stream remains downstream evidence; it never reconstructs or mutates operational VMM trading/synthetic state.


### One book, multiple reporting views

`VMMAccountingReportingService` does not create desk ledgers. It projects the one durable `VECTOR_MERIDIAN_MARKETS_LTD / VMM-STAT` book through evidence-bearing boundaries. `vmm.businessLine` separates institutional-synthetic activity from treasury funding; `vmm.accountingFunction` separates premium, collateral/custody, XVA, close-out and funding. The same immutable journal may therefore appear in whole-firm and one relevant filtered view without being reposted.

The VMM wrapper accepts only boundaries scoped to the VMM legal entity and `VMM-STAT`. Federation may be named as an arm's-length funding counterparty dimension but cannot be included as a reporting entity. The dimensions are persisted on journal lines and therefore survive AccountingFileStore restart.

Accounting Core v0.7 also exposes generic tax and settlement facilities, but v0.11 does not infer a VMM tax/rounding policy from their existence. Access Permissions v0.1 is likewise not applied decoratively to Queue Fabric message boundaries; exact object-method permission enforcement belongs at an actual Security Manager object boundary.

## Company boundary

The Federation/VMM protocol is unchanged at `vmm.federation.arm_length/0.3`. Federation may PUT RFQs and execution instructions and GET VMM quotes/confirmations. VMM has the inverse queue permissions. The RFQ carries exact instrument/economic information, source authority and an opaque relationship reference but no customer legal-identity field.

## Execution boundary

`vmm.execution/0.4` carries the queue-persistable order lifecycle objects. v0.4 adds optional route targeting on commands and optional route/fee/rebate data on fills while retaining the existing persistent payload type IDs.

The v0.3 single execution service remains valid. `VMMSmartExecutionService` is an additional execution-service implementation accepted by `VectorMeridianMarkets.bindExecutionService()`.

## Smart routing

A `VMMVenueRoute` is an independently attributable access path, not just a string in a price table. It has its own Queue Fabric principal and durable route queue, executing counterparty, jurisdiction, fee/rebate schedule, capacity, policy reference and evidence.

The smart router consumes firm `VMMVenueQuote` objects and chooses the best eligible route only after checking:

1. route active state;
2. exact venue/listing compatibility with the order's `VMMTradableInstrument`;
3. quote validity and available notional;
4. VMM market/compliance restrictions;
5. VMM firm-risk and capital constraints;
6. short-locate capacity where the order creates new short exposure;
7. fee/rebate-adjusted executable economics.

The resulting `VMMSmartRouteDecision` is evidence that VMM made its own execution decision. Federation does not pick or invoke a VMM venue adapter.

## Tradable-line identity versus economic equivalence

VMM inventory remains keyed by exact legal tradable line: ISIN + listing/venue MIC + relevant currencies. The smart router does not silently change the venue MIC.

`VMMMarketStructureLink` is a separate relationship between distinct lines. It can state `FUNGIBLE` or `HEDGE_EQUIVALENT` while status is `ACTIVE`. A sanctions/custody/transfer event may change it to `IMPAIRED`, `BROKEN` or `SUSPENDED`. Historical inventory remains on its original line throughout.

This makes the market-structure rule explicit: X≈Y is evidence that can expire or be broken; it is not identity.

## Short locate

Smart-routed new short exposure requires a `VMMShortLocate`. Routing reserves only the extra negative inventory the order could create. Actual fills consume reservation as the position becomes more short. Terminal rejection/cancellation releases unused reservation. Closing existing long inventory does not consume borrow merely because the order side is `SHORT`.

## Capital and funding

VMM funding and VMM capital are different books:

- `VMMFundingFacility` creates VMM debt and funding cash;
- `VMMCapitalPolicy` supplies VMM capital base and maximum leverage;
- projected gross exposure is checked against the VMM capital policy during pre-trade admission;
- `VMMCapitalSnapshot` records resulting leverage.

Federation lending therefore cannot be relabelled as VMM equity to evade leverage controls.

## Post-trade truth

A routed venue fill remains authoritative even after a kill switch, strategy disablement, new sanctions restriction or tightened capital limit. Pre-trade controls decide whether VMM may send new risk; they do not rewrite facts already executed externally.

Fill state now retains route, fee and rebate evidence. `VMMMarketOrder` aggregates fill notional, weighted average price, gross fees, rebates and net execution cost.

## Kill switch

For local/unrouted orders VMM may cancel immediately. For routed orders the kill switch sends a cancel command to the route originally selected and records `CANCEL_PENDING`. A venue fill may race that cancellation and must be booked before any cancellation confirmation terminates the remainder.

## JSON/API role

JSON remains an adapter serialization. `VMMExecutionJsonAdapter` has no engine reference and only publishes Queue Fabric execution events. The canonical semantics therefore survive a future switch among FIX, REST/JSON, WebSocket, Java, Python or simulated adapters.
