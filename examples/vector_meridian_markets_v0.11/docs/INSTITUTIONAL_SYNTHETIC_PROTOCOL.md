# VMM institutional synthetic protocol v0.5

Protocol: `vmm.institutional.synthetic/0.5`

This is a **direct VMM institutional OTC** boundary. It is not the Federation Merchant anonymised RFQ channel.

## Durable queues

- `VMM.INSTITUTIONAL.SYNTHETIC.REQUEST` — institutional client PUT, VMM dealer GET.
- `VMM.INSTITUTIONAL.SYNTHETIC.OFFER` — VMM dealer PUT, institutional client GET.
- `VMM.INSTITUTIONAL.SYNTHETIC.ACCEPT` — institutional client PUT, VMM dealer GET.
- `VMM.INSTITUTIONAL.SYNTHETIC.CONFIRM` — VMM dealer PUT, institutional client GET.

The client principal is explicit per service instance. Federation principals are not granted any rights on these queues.

## Request

The request references a portfolio snapshot already accepted into VMM's controlled institutional-product store. It carries counterparty/legal source identity, exact snapshot ID, product type, currency, requested notional and maturity. The raw position set is not sent through the trading/execution queues.

v0.5 supports `PORTFOLIO_LOSS_PROTECTION` only.

## Offer

VMM's dealer creates an evidence-backed offer with:

- exact snapshot ID;
- protected notional;
- attachment and exhaustion loss percentages;
- premium amount;
- effective date / maturity / offer validity;
- model evidence;
- market-data evidence;
- VMM independent risk approval.

Open offers consume synthetic risk capacity so VMM cannot evade limits by issuing multiple unaccepted quotes.

## Acceptance / confirmation

Acceptance must come from the same legal entity/counterparty channel as the request. VMM books its own `VMMSyntheticContract` under the VMM-counterparty master agreement and collateral agreement, then emits a confirmation.

## Portfolio snapshot and merger provenance

Each position identifies current legal owner, issuer, source book, valuation evidence and optional legacy owner. If legacy owner differs from current owner, position-level succession evidence is mandatory, and the overall snapshot must carry merger/succession evidence.

The snapshot is immutable. In VMM v0.6, later rebalance, merger adjustment, portfolio substitution or corporate action creates a new snapshot plus an explicit `VMMReferencePortfolioChange`; historical snapshot evidence is never overwritten. Client-originated changes cross `vmm.institutional.synthetic.lifecycle/0.6` and still require VMM risk approval.

## Risk

Before creating an offer VMM checks its own synthetic risk policy:

- aggregate synthetic protected notional;
- single institutional counterparty protected notional;
- wrong-way reference concentration;
- no self-reference to `VECTOR_MERIDIAN_MARKETS_LTD`.

A Federation-related issuer can be designated wrong-way because VMM may simultaneously rely on Federation funding. That is VMM's risk classification and does not give Federation access to the client portfolio.

## Valuation / collateral

Independent valuation records portfolio value, portfolio loss %, protection fraction and current VMM liability estimate. Collateral terms support threshold, minimum transfer amount and independent amount. Collateral transfers require a third-party custodian/control evidence reference.

## Hedge separation

A contract may create VMM `SYNTHETIC_HEDGE` market orders. The execution command contains the VMM contract reference plus VMM-selected exact tradable hedge line. It does not transmit the insurer's position list. Existing `vmm.smart-execution/0.4` remains the hedge execution authority.


## v0.6 post-trade lifecycle extension

Contract formation remains on this `/0.5` protocol for compatibility. VMM v0.6 adds the separate `vmm.institutional.synthetic.lifecycle/0.6` boundary documented in `INSTITUTIONAL_LIFECYCLE_PROTOCOL.md`. It covers premium-payment notices and reference-change requests without widening the original formation schema.

Premium schedules/accruals, initial margin/haircuts, portfolio lineage, novation, CVA/FVA and hedge-effectiveness records are VMM lifecycle objects. Novation remains a VMM-controlled tripartite operation because outgoing, incoming and VMM authorities must all be present.
