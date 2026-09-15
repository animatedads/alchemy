# VMM Smart Execution Protocol v0.4

Protocol/header identity: `vmm.smart-execution/0.4`

## Admission order

A VMM smart order is admitted in this order:

1. an order already exists in VMM from a completed inventory-hedge parent or independent proprietary decision;
2. the router finds an active route on the same exact venue/listing MIC;
3. the route has a current firm quote with sufficient available notional;
4. VMM market restrictions permit new execution;
5. VMM firm-risk and capital checks pass;
6. any incremental short exposure is covered by a live locate reservation;
7. the router records a `VMMSmartRouteDecision` using fee/rebate-adjusted executable price;
8. only then is a persistent `VMMExecutionCommand` PUT onto the selected route queue.

No order rejected in steps 2-6 creates an external command package.

## Route economics

For a LONG order, effective cost is:

`ask * (1 + (feeBps - rebateBps)/10000)`

For a SHORT order, effective proceeds are:

`bid * (1 - (feeBps - rebateBps)/10000)`

The router minimises effective cost for buys and maximises effective proceeds for sells. Deterministic route priority and route ID break exact ties.

## Route isolation

Every route names a dedicated Queue Fabric adapter principal. A venue adapter can only claim from its registered route queue. The command also carries `routeId` and `targetAdapterId`; a mismatched adapter must nack/fail rather than execute the command.

## Short-locate semantics

A locate covers only newly created negative inventory. The required amount is the increase in absolute short inventory between current and projected state.

Reservation precedes queue admission. Partial fills consume only the portion of locate that actually becomes short. Rejection/cancellation releases the unused reserved portion. Consumed borrow remains attributable to the open short position.

## Restrictions and sanctions

`VMMMarketRestriction` is evaluated before route queue admission. `SETTLEMENT_IMPAIRED`, `BLOCK_NEW` and `PRICE_UNRELIABLE` block new smart execution. `CLOSE_ONLY` permits only position-reducing execution.

`VMMMarketStructureLink` is separate from restriction state and inventory identity. A sanctions or transfer-control event can set a prior hedge/fungibility relationship to `BROKEN` without relabelling either tradable line.

## Capital

`VMMCapitalPolicy` limits projected gross exposure to `capitalBase * maxLeverage`. It is VMM-owned independent risk policy. Borrowed money from Federation or another wholesale lender does not increase `capitalBase` unless a separately authorised VMM capital action changes the policy.

## Fill accounting

The adapter computes actual fee and rebate amounts for each fill from the configured route schedule. Those amounts travel with the fill event. VMM separately records gross fee, rebate and net cost, and includes net execution cost in trading cash/P&L.
