# VMM Front-End Boundary

## Owned here

- VMM browser bootstrap and branding shell;
- responsive presentation recipes;
- accessibility and renderer-facing CSS;
- non-authoritative visual fixtures;
- exact Builder-authored VMM operator interaction release;
- browser-only validation and Builder/Server compatibility fixtures.

## Not owned here

- RFQ / quote creation;
- algorithm strategy decisions;
- route selection;
- order validation or execution;
- acknowledgements, fills or reconciliation truth;
- tradable-line identity or inventory;
- P&L calculation;
- capital / leverage / loss limits;
- locate / borrow truth;
- synthetic valuation, margin, collateral, default or close-out;
- funding balances or interest;
- Accounting Core posting / reporting;
- FederationBank authority.

## Separation rule

The live page receives a server-authoritative projection. It must not obtain a `VMMMarketMaker`, `VMMExecutionService`, `VMMInstitutionalSyntheticService`, `VMMAccountingService` or other business object reference.

FederationBank identities may be displayed only when VMM projects them as arm's-length counterparty/lender evidence. Federation credentials, Core account identities and customer legal identities must never be browser configuration.

## Action rule

v0.2 distinguishes three layers explicitly:

1. **Builder release** — defines semantic operator intents such as `VMM.ORDER.CANCEL.REQUEST`.
2. **Wire UI Server** — binds an exact definition to an exact instance and records whether that action was available at the rendered revision.
3. **VMM application/domain authority** — decides whether an admitted operator intent may cause a VMM business transition.

The live browser shell contains no hard-coded VMM action vocabulary. It cannot manufacture an action merely because the user can see a button-shaped element.

A live action must match the exact application/session/access-point/view/instance/release/revision context and have been server-available at that revision before application dispatch occurs.

## Preview rule

`web/preview.html` may display sample action names so humans can review the intended information architecture. It is marked `NON-AUTHORITATIVE PREVIEW`, performs no network calls and contains no live Queue Fabric/Wire UI transport.
