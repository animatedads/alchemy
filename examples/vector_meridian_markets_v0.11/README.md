# Vector Meridian Markets Ltd v0.11

Vector Meridian Markets Ltd (VMM) is the deliberately separate principal market-making company in the FederationBank test universe.

Legal entity: `VECTOR_MERIDIAN_MARKETS_LTD`

## v0.11 headline: one VMM book, evidence-bound reporting views on Accounting Core v0.7

v0.11 adopts Accounting Core v0.7 without changing VMM's legal perimeter or operational protocols. VMM still owns one durable statutory book: `VECTOR_MERIDIAN_MARKETS_LTD / VMM-STAT / ENTITY_GAAP`. The new `VMMAccountingReporting.cls` uses Accounting Core `accounting.reporting/0.1` and `accounting.scope/0.1` to derive immutable management/regulatory views from already-posted VMM journals. A reporting boundary is a projection over one legal-entity book; it is not a second ledger, a desk company, or authority to repost transactions.

The VMM accounting adapter advances to `vmm.accounting/0.11`, persistence to `vmm.accounting.persistence/0.11`, and reporting is exposed as `vmm.accounting.reporting/0.11`. Accounting Core event/transaction/posting/store APIs remain `accounting.event/0.1`, `accounting.transaction/0.1`, `accounting.posting/0.2`, and `accounting.store/0.1`. Package-level `::OPTIONS DIGITS 50` remains mandatory.

VMM now stamps exact accounting dimensions on new journals: `vmm.businessLine` distinguishes `INSTITUTIONAL_SYNTHETICS` from `TREASURY_FUNDING`, while `vmm.accountingFunction` distinguishes premium, collateral/custody, XVA, close-out and funding activity. `VMMAccountingReportingBoundaryFactory` creates evidence-bearing whole-firm, institutional-synthetics, treasury-funding, collateral/custody, close-out and XVA boundaries. `VMMAccountingReportingService` refuses boundaries that include any legal entity or book other than VMM / `VMM-STAT`. FederationBank can therefore appear inside the treasury-funding view as a lender/counterparty dimension without becoming a reporting entity, book owner or accounting authority.

The reporting dimensions and boundary results survive `AccountingFileStore` restart because they are projections of the same immutable durable journals. v0.11 deliberately does not adopt Accounting Core v0.7 tax determination or cash-settlement-rounding policy into VMM merely because those generic facilities exist. `oorexx_access_permissions_v0.1` is present in the integration roll-up but is likewise not decoratively wired into queue-facing VMM boundaries; exact object×method permissions will be introduced only where VMM actually exposes protected object methods through Security Manager.

The current roll-up also advances qualification to FederationBank Merchant Bank v0.15 and ooRexx Crypto v0.5 (transitively through Queue Fabric). All Japan Insurance v0.9 is the current independent institutional-counterparty package but is not a VMM runtime dependency.

## v0.10 headline: durable 50-digit VMM accounting on Accounting Core v0.4

v0.10 adopts the supplied Accounting Core v0.4 as VMM's accounting baseline. `VMMAccounting.cls` now compiles under `::OPTIONS DIGITS 50`, matching Accounting Core's package-level arithmetic contract; a future VMM policy package compiled below 50 digits is rejected before registration rather than being allowed to round institutional minor-unit amounts.

The accounting adapter advances to `vmm.accounting/0.10` and exposes Accounting Core's new `accounting.store/0.1`. `VMMAccountingStore` creates and recovers VMM's `VMM-STAT` statutory book through the append-only `AccountingFileStore`. The durable stream persists VMM book identity, chart mutations, periods and period transitions, immutable journals, source-event fingerprints and exact executable `policyIdentity`. Recovery re-registers VMM policy only for genuinely new events; exact historical replay/conflict is resolved from recovered journal identity first.

This is accounting persistence only. It does not reconstruct VMM trading inventory, synthetic-contract state or Queue Fabric state from the accounting journal, and it does not grant FederationBank or an institutional counterparty any authority over VMM's book. A recovered store must identify `VECTOR_MERIDIAN_MARKETS_LTD`, `VMM-STAT` and `ENTITY_GAAP` or VMM refuses to adopt it.

`VMMAccountingPeriodControl` also makes close/reopen/lock operations evidence-bearing VMM actions. Actor, reason, evidence and occurrence time survive restart; a locked period remains locked after recovery. Premium cumulative accrual continues to derive its incremental delta from recovered posted accounting truth, demonstrated with the existing ¥120m premium (12,000,000,000 minor units).

VMM is neither FederationBank Core/Retail Banking nor FederationBank Merchant Banking. Federation entities can lend to or trade with VMM only through explicit arm's-length contracts and Queue Fabric message boundaries. VMM owns its algorithms, principal inventory, execution state, stock-borrow obligations, capital/risk controls, surveillance evidence and P&L.

## v0.9 headline: close-out disputes, finalization, master-agreement netting and custody return

v0.9 keeps the v0.8 default/termination determination immutable and adds the post-determination operations needed before cash can safely move. A close-out may be disputed during an evidence-bound window, independently revalued by a configured fallback valuation agent, and then finalized. Finalization is a new immutable authority object; neither a dispute nor its resolution edits the original v0.8 close-out determination.

The new Queue Fabric protocol `vmm.institutional.synthetic.closeout/0.9` carries institutional valuation-dispute instructions plus VMM result/finalization notices. The client gateway remains queue-only and has no VMM/default/close-out service reference. Federation principals have no ACL on this boundary.

Undisputed close-outs cannot be finalized until the dispute window has expired. Disputed close-outs cannot settle until independently resolved. The original termination valuation agent cannot simply appoint itself as the fallback agent. Settlement authority therefore becomes an exact `VMMCloseoutFinalization`, with basis `ORIGINAL_UNDISPUTED` or `DISPUTE_RESOLUTION`, source evidence and final signed amount from VMM's perspective.

### Evidence-bound master-agreement netting

`VMMMasterAgreementNettingSet` permits multi-contract set-off only when every member has the exact same disclosed counterparty, master agreement, currency and legal perimeter, and explicit governing-law, legal-opinion and close-out-netting-election evidence is present. A valid set preserves gross receivable and gross payable totals and produces one legal net cash amount. Once fixed into a netting set, a member close-out cannot be settled individually. Cross-counterparty or cross-master-agreement convenience netting is rejected without mutating either close-out.

Segregated initial margin remains outside close-out/netting algebra. After the relevant cash close-out is settled, VMM may instruct return of the exact originally transferred collateral through a custodian lifecycle: instruction -> acknowledgement -> settlement. Gross carrying value returns to VMM; the historical haircut-adjusted risk value remains evidence rather than an accounting loss.

### v0.9 accounting recognition point

The VMM accounting adapter advances to `vmm.accounting/0.9` while retaining Accounting Core `accounting.event/0.1`, `accounting.transaction/0.1` and `accounting.posting/0.2`. When the v0.9 close-out operations controller is bound, accounting recognizes the finalized legal amount rather than an unresolved/disputed v0.8 determination. Separate policies record finalization, final cash settlement, legally evidenced master-agreement net settlement and segregated-IM custody return.

The new `oorexxapis(20260828-155014)` roll-up advances ooRexx Crypto to v0.4; VMM v0.9 is qualified against it. The roll-up's VMM v0.7 and unpatched Accounting Core v0.3 are older than this workstream, so v0.9 deliberately retains qualified Accounting Core v0.3.1.

## v0.8 headline: default, cure, early termination and evidence-bound close-out

v0.8 adds a bilateral institutional default/close-out layer without collapsing distinct legal steps. A default notice does not terminate a contract; cure is allowed only to the contractual deadline; an uncured assessment is required before the non-defaulting party may elect early termination; close-out valuation is then an immutable determination; settlement is a later cash fact.

The new Queue Fabric boundary `vmm.institutional.synthetic.default/0.8` carries bilateral default notices, client cures and client termination elections. All Japan (or another direct VMM institutional counterparty) has queue access only and no VMM service/engine reference. Federation principals have no ACL on the default queues. A client may cure only its own default and may elect termination only when VMM is the defaulting party and the client is the non-defaulting party.

Close-out uses a signed VMM-perspective amount: positive is a VMM receivable and negative is a VMM payable. Evidence-backed cash variation margin can enter close-out netting; segregated initial margin is disclosed separately and is **not silently netted**. Internal hedge unwind P&L is separate VMM attribution evidence and cannot be inserted into the institutional client's legal close-out amount merely because VMM hedged badly.

## v0.8 accounting: AccountingEvent -> effective policy -> immutable VMM journal

The accounting adapter advances to `vmm.accounting/0.8` and targets Accounting Core `accounting.event/0.1`, `accounting.transaction/0.1` and `accounting.posting/0.2`. Normal VMM operational accounting now uses `AccountingEngine~transact()` with effective-dated VMM policy identities instead of constructing journals directly. Replay is checked before policy execution, and every posted journal retains the source-event fingerprint and exact executable policy identity.

Premium, collateral, funding and XVA mappings are retained. v0.8 additionally accounts for legal close-out determination and later settlement. Gross contractual close-out gain/loss, cash-VM disposal and the resulting net receivable/payable remain separate lines. Segregated IM remains outside automatic close-out netting unless a later evidence-backed legal policy explicitly changes that treatment.

The supplied Accounting Core v0.3 reintroduced the large-minor-unit validation ordering defect previously found in v0.2: `DATATYPE(...,"W")` ran before the higher numeric precision took effect. `accounting_core_v0.3.1` is the narrow repaired dependency; it moves high precision before validation and adds a 12,000,000,000-minor-unit transaction-path regression. The public v0.3 APIs are unchanged.

## v0.7 headline: VMM gets its own real Accounting Core book

v0.7 integrates the shared Accounting Core behind an explicit VMM accounting-policy adapter. Operational VMM objects remain authoritative for trades, funding, synthetic contracts, premium, collateral and XVA; accounting consumes accepted source events and posts only `VECTOR_MERIDIAN_MARKETS_LTD` books. There is no shared Federation/VMM ledger and no cross-company posting capability.

`vmm.accounting/0.7` targets `accounting.posting/0.1`. It maps synthetic premium accrual/settlement, VMM-posted variation margin, initial-margin asset reclassification, arm's-length funding draw/accrual/repayment and VMM XVA adjustments into immutable Accounting Core journals. Source-event IDs are used as Accounting Core idempotency keys, so replay is safe and conflicting reuse is rejected.

Initial-margin haircuts are deliberately not booked as accounting write-downs: the collateral asset is reclassified at gross carrying value while haircut-adjusted recognised value remains a risk/evidence dimension. Likewise CVA/FVA can create VMM accounting adjustments but cannot rewrite the contractual synthetic payoff or independent valuation object.

The supplied Accounting Core v0.2 exposed one integration blocker at institutional scale: its whole-number minor-unit validator evaluated `datatype(..., "W")` under ooRexx's default 9-digit precision. v0.2.1 is a narrow compatibility repair that performs that validation under `numeric digits 50`, matching the posting engine's existing exact-minor-unit design. The posting API remains `accounting.posting/0.1`.

## v0.6 headline: post-trade synthetic lifecycle without collapsing accounting truths

v0.6 takes the direct institutional synthetic desk through premium, collateral, reference-portfolio and counterparty lifecycle. Contractual payoff value remains distinct from premium/collateral cash and from VMM-only CVA/FVA/hedge-effectiveness evidence. XVA therefore cannot rewrite what VMM contractually owes, and an ineffective hedge is recorded as a VMM risk fact rather than discarded.

Premium schedules must sum exactly to the accepted contractual premium. Cumulative accrual uses explicit elapsed/total-day evidence, and settlement is externally evidenced from the disclosed institutional legal entity to `VECTOR_MERIDIAN_MARKETS_LTD`. Initial margin is separate from variation margin and recognises collateral after explicit asset-level haircuts.

Reference portfolio substitutions and corporate actions advance through immutable successor snapshots. Client substitutions are subject to VMM lifecycle value-drift policy and current wrong-way-risk checks. Novation is tripartite: the old contract becomes `NOVATED`, a new legal contract is created for the incoming counterparty under its own master/collateral agreements, and successor-owned reference evidence is required.

## v0.6 institutional lifecycle queue boundary

Post-trade client-originated premium-payment notices and reference-change requests use `vmm.institutional.synthetic.lifecycle/0.6` over dedicated durable Queue Fabric instruction/result queues. The institutional gateway has no VMM engine/service reference, and Federation principals have no ACL. Contract formation deliberately remains compatible on `vmm.institutional.synthetic/0.5`.

## v0.5 headline: direct institutional synthetic products without Federation visibility

v0.5 adds a separate VMM institutional OTC product line for bespoke portfolio-linked synthetic protection. A direct institutional client is a disclosed VMM legal counterparty for KYC, master-agreement and collateral purposes; it is **not** routed through FederationBank's anonymised merchant RFQ channel.

The first executable product is `PORTFOLIO_LOSS_PROTECTION`. It references an immutable, evidence-backed portfolio snapshot, uses explicit attachment/exhaustion loss points, records independent model/market-data/risk approvals, books a VMM OTC contract, supports independent valuation and variation-margin collateral, and can create VMM-owned hedge orders that enter the existing Queue Fabric smart-execution spine.

Recently merged portfolios are modelled explicitly: inherited positions retain legacy-owner/source-book provenance and require succession evidence before the current legal owner can include them in a VMM reference snapshot.

## Institutional synthetic queue boundary

Direct institutional request/offer/accept/confirmation uses `vmm.institutional.synthetic/0.5` over four durable Queue Fabric queues. The client gateway has only Queue Fabric access; it has no `VectorMeridianMarkets` engine or product-service reference. Federation principals receive no ACL on these queues.

This boundary deliberately separates two very different client paths:

1. Federation Merchant -> VMM remains anonymised `vmm.federation.arm_length/0.3` flow; VMM does not learn the Federation customer's legal identity.
2. A direct institutional OTC client is VMM's own disclosed counterparty because VMM itself must perform KYC, contract, collateral and lifecycle management.

The client's raw portfolio does not flow into VMM market-execution commands. Hedge orders carry the VMM synthetic contract reference and VMM-selected tradable hedge instrument only.

## Synthetic risk and collateral controls

`VMMSyntheticRiskPolicy` independently caps VMM aggregate synthetic notional, single-institution concentration and wrong-way reference concentration. Funding-dependency entities such as Federation-related issuers can be tagged as wrong-way references; VMM will reject a new synthetic offer before contract booking when the configured concentration limit is exceeded. VMM also refuses to write portfolio protection referencing itself.

`VMMPortfolioLossProtectionTerms` defines protected notional, attachment loss %, exhaustion loss %, premium, effective date and maturity. `VMMSyntheticValuation` records current portfolio value, loss %, protection fraction and VMM liability estimate with independent market/model evidence. `VMMSyntheticCollateralTerms`, `VMMVariationMarginCall` and `VMMSyntheticCollateralTransfer` model threshold/MTA/independent-amount collateral with externally attributable custodian/control evidence.

A synthetic contract hedge is created with origin `SYNTHETIC_HEDGE`, distinct from both `INVENTORY_HEDGE` and `PROPRIETARY_SIGNAL`, then routed through the same smart-execution queues as other VMM market orders.

## v0.4 smart execution retained: smart execution without weakening legal identity

v0.4 adds a Queue Fabric-native smart execution layer on top of the v0.3 lifecycle. The router can rank multiple independent execution channels for the **same exact tradable line** using firm market quotes plus fees/rebates, then send the command only to the selected adapter's durable route queue.

It deliberately does not treat a cheaper cross-listing as the same asset. ISIN/listing/currency inventory identity remains exact. Any economic/fungibility relationship between different lines is represented separately by `VMMMarketStructureLink`, and sanctions or transfer restrictions can change that link to `IMPAIRED`, `BROKEN` or `SUSPENDED` without rewriting historical positions.

## Canonical queue boundaries

1. **FederationBank Merchant Banking <-> VMM** uses the unchanged arm's-length protocol `vmm.federation.arm_length/0.3` for anonymised RFQ / quote / execution instruction / trade confirmation.
2. **VMM <-> external execution** uses `vmm.execution/0.4`. The original single-adapter service remains source compatible.
3. **VMM smart router <-> venue/access adapters** uses `vmm.smart-execution/0.4`, with one durable command queue per registered route and a shared durable event queue.

JSON remains an edge representation. It may create Queue Fabric events but cannot mutate VMM inventory directly.

## Smart route model

`VMMVenueRoute` defines an independently attributable execution channel with:

- route ID and exact venue MIC;
- adapter ID and dedicated Queue Fabric principal;
- executing counterparty and jurisdiction;
- fee and rebate basis points;
- maximum order notional and deterministic priority;
- execution-policy and route-evidence references;
- active/paused/restricted state.

`VMMVenueQuote` supplies firm bid/ask, available size and validity. `VMMSmartRouteDecision` records the selected route, source quote, raw price, fee/rebate-adjusted effective price and evidence.

For a buy, the router minimises effective acquisition cost. For a sell, it maximises effective proceeds. Raw price alone is never enough to win routing.

## Exact asset identity and market structure

`VMMTradableInstrument.identityKey` continues to include ISIN, venue/listing MIC, denomination currency, quote currency and settlement currency. The smart router will reject a route whose venue MIC would silently change that legal tradable line.

`VMMMarketStructureLink` records a separately evidenced relationship such as `FUNGIBLE` or `HEDGE_EQUIVALENT` between two distinct lines. A sanctions, custody, transfer or settlement event can break that relationship while each underlying inventory line remains unchanged.

## Short sale locate / borrow

`VMMShortLocate` is VMM-owned stock-borrow evidence. New short exposure admitted through the smart router requires sufficient active locate capacity before a Queue Fabric command is created.

A locate is split into reserved and consumed capacity:

- routing reserves only the additional short exposure;
- actual short fills consume the relevant reservation;
- venue-confirmed rejection/cancellation releases unused reserved capacity;
- consumed borrow remains consumed after cancellation of the remainder.

Closing an existing long position does not require a locate merely because the order side is `SHORT`; only newly created negative inventory does.

## Market restrictions

`VMMMarketRestriction` is a VMM compliance/market-structure admission control scoped to an instrument line and/or venue. Supported effects are:

- `BLOCK_NEW`;
- `CLOSE_ONLY`;
- `SETTLEMENT_IMPAIRED`;
- `PRICE_UNRELIABLE`.

The smart router applies restrictions before queue admission. A blocked order therefore creates no external command and remains unrouted. Historical fills are not erased when a later restriction appears.

## Capital and leverage

`VMMCapitalPolicy` is independent of FederationBank funding. It supplies a VMM capital base and maximum leverage for a currency. Projected gross exposure is checked against `capitalBase * maxLeverage` during current pre-trade admission, and `VMMCapitalSnapshot` records post-trade leverage evidence.

This is deliberately separate from `VMMFundingFacility`: borrowed Federation/wholesale money is a VMM liability, not VMM equity capital.

## Fees, rebates and partial fills

`VMMExecutionFillEvent` and `VMMExecutionFill` now carry optional route ID, fee amount and rebate amount. Existing v0.3-style events remain compatible because the new fields are optional and the persistent type identity is unchanged.

`VMMMarketOrder` aggregates:

- filled notional;
- weighted average execution price;
- gross execution fees;
- execution rebates;
- net execution cost.

Trading cash is adjusted for the fill economics and net execution cost. Fees/rebates therefore affect marked trading P&L rather than living only in route metadata.

## Hard separation rules retained

- no FederationBank customer/Core account debit capability exists in VMM;
- `CUSTOMER_DEPOSIT` cannot fund VMM;
- Federation's queue client has no VMM engine reference;
- the Federation/VMM RFQ contains no customer legal-identity field;
- external hedge orders require a completed VMM principal trade;
- proprietary orders require separately evidenced algorithm decisions;
- direct `fillMarketOrder()` is rejected once Queue Fabric execution is bound;
- a real venue fill is post-trade truth even if a kill switch or later risk change would reject the trade today;
- routed cancellation remains `CANCEL_PENDING` until venue confirmation;
- VMM risk, capital, locate and compliance controls are VMM authority, not FederationBank inherited authority.

## Validation

Validated with the supplied ooRexx 5.3.0 r13196 runtime and `oorexxapis(20260828-132447).zip`:

- VMM v0.6: `PASS 35/35`;
- FederationBank Merchant Bank v0.13 unchanged regression: `PASS 41/41`;
- Queue Fabric targeted basic/adversarial/MQ/channel/release-boundary suites pass with 62 / 71 / 141 / 85 / 10 assertions respectively;
- all 8 VMM source/integration `.cls` files compile with `rexxc`.

See `VALIDATION.txt`, `docs/INSTITUTIONAL_SYNTHETIC_PROTOCOL.md`, `docs/SMART_EXECUTION_PROTOCOL.md` and `HANDOVER.md` for exact scope and invariants.
