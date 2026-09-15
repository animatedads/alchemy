# Early UI projection requirements

This document is a front-end consumption contract, not a Merchant-domain API and not an authority model.

The live Wire UI application release should project bounded scalars/collections with source/revision/evidence references sufficient to render these views. The browser must not derive the values below from adjacent fields.

## Overview

Required independent projections:

- client presentation state;
- live contractual leg count and contract identifiers;
- whole-book directional exposure;
- current whole-book risk state;
- remediation obligation/work summary;
- settlement obligation/status summary;
- Merchant accounting-control summary;
- valuation timestamp / revision.

Never infer `riskClosed` from client `CLOSED`, net-zero exposure, settlement completion or a completed work item.

## Positions

For each customer-rooted hedge graph:

- economic root / hedge-set identity;
- original and reversing contract identities;
- contract lifecycle state;
- client presentation state;
- economic exposure state;
- instrument-resolution and settlement-line descriptors;
- immutable hedge-equivalence evidence reference/version;
- counterparty / FX / basis / fungibility / custody risk projections.

Never infer exact offset from ticker, ISIN or venue equality.

## Remediation

Plan projection:

- plan id/status;
- bound assessment id/revision;
- proposer and approver attribution (presentation-safe identities);
- approved step sequence and expected scalar effects;
- approved projected final exposure;
- approved `peakAbsBaseExposure`.

Execution projection:

- dispatch evidence reference/status where present;
- terminal/non-terminal execution observation status;
- intended versus observed side/quantity/instrument/settlement-line/FX evidence;
- checkpoint timestamp/revision;
- actual whole-book exposure at checkpoint;
- checkpoint assessment and diagnostic reason;
- retained prior-divergence flag/state;
- resulting remediation obligation state and risk-work references.

Never infer successful execution from an approved plan, dispatch, operator statement, final net-zero result or work-item completion.

## Settlement

Required evidence chain:

- Merchant settlement obligation id, side, amount, currency and counterparties;
- instruction evidence id/status/amount;
- external observation evidence id, external receipt identity, source authority, partial/full/failed status and amount;
- cumulative observed amount and resulting Merchant settlement status.

Never display an instruction as observed cash.

## Accounting

Required projections are read from the independent Merchant accounting book / adapter boundary:

- source-event reference/fingerprint;
- journal id/status;
- semantic policy reference and exact executable policy identity where relevant;
- settlement receivable/payable carrying amount;
- cash-at-settlement-agent carrying amount;
- derivative-settlement control carrying amount;
- whether derivative derecognition/realised-P&L evidence remains outstanding;
- optional settlement amount determination, election/ruleset identity, determined amount, difference and authority result.

Never infer accounting completion from cash settlement. Never display a non-posting settlement amount determination as an amended Merchant contractual obligation.

## Market structure

Required projections:

- `MBMarketStructureEvent` reference/time/type;
- affected instrument-resolution identities;
- immutable `MBHedgeEquivalenceEvidence` version/reference;
- hedge classification (`EXACT_OFFSET`, `SETTLEMENT_LINE_HEDGE`, `CROSS_LISTED_HEDGE`, `RELATED_HEDGE` or later authoritative value);
- resulting whole-book hedge/risk state.

A legal/custody event may change the projected result without a fresh price tick.

## Command boundary

v0.2 intentionally defines no hard-coded business command in browser code. A future live release may expose semantic actions only through server-authoritative Wire UI definitions and the authenticated security context. Presentation role/profile must never substitute for Access Control, exact method/object Permission or Security Effect decisions.

## v0.3 live workspace contract

The first live semantic release was `FEDERATIONBANK_MERCHANT_OPERATIONS@2026.08.28.1`. The current v0.6 release is `FEDERATIONBANK_MERCHANT_OPERATIONS@2026.09.01.1`, shipped as `semantic/federationbank_merchant_operations_v0.6.json`. Its `FBM.BOOKS` collection remains server-owned and bounded. Filtering changes membership scope and invalidates stale selection scope; sorting is server-owned ordering; selecting a book projects its independent detail/evidence panels.

## v0.4 authority projection contract

`FBMerchantWireAuthorityProjectionAdapter` is now the production-shaped source for the bounded v0.3 interaction model. It must:

- discover only customer-rooted CFD books that already have an authoritative Merchant whole-book assessment;
- bind Risk Service to the exact Merchant Bank object and accounting to the same Merchant legal entity;
- read remediation execution/checkpoint facts from Merchant Bank and operational attention from Risk Service without creating either;
- project settlement only when the obligation source execution is provably bound to the selected portfolio;
- derive accounting status only from immutable Accounting Core journal entries correlated to the exact settlement obligation;
- never invent persisted settlement-rounding determination state where Accounting Adapter v0.5 retains no such authority fact;
- preserve whole-book state separately from exact hedge/market-structure impairment state;
- re-read authorities on explicit `WORKSPACE.REFRESH`; and
- omit unbound/missing facts rather than synthesize a reassuring default.

Filtering/sorting/selection are operations over the current server-owned read projection. They are not authority refreshes and cannot create Merchant/Risk/Accounting evidence.

## v0.5 first-class row/list/window contract

`FBM.BOOKS` must render predictably as 0/1/N rows without browser reinterpretation of a collection value. The collection is represented structurally by semantic child row instances; counts remain separate scalar metadata.

Required collection metadata:

- `collectionRef`;
- `windowOffset` and `windowLimit`;
- `windowTotalCount` for the total matching semantic membership;
- `visibleRowCount` for only the currently materialised window;
- `windowRevision`;
- independent `queryRevision`, `scopeRevision`, `orderRevision`, `selectionRevision`, and `resultRevision`.

Every book row has a stable semantic identity, `semanticRowId = rootTradeId`. No action, detail projection or selection may bind to a visible row number or current position.

Filtering changes membership scope and therefore invalidates selection. Sorting preserves selection identity where membership is unchanged. Paging/windowing may remove a selected row from the renderer's current child list but must not change semantic selection or selected-book detail. A selected book remains selected by its server-owned ID, not by its former visible position.

`resultRevision` is independent of `selectionRevision` and `windowRevision`. Selecting or paging does not create a new business result. A change to authoritative projected row/business facts does advance the result revision even where selection is unchanged.

The `FBM_BOOK_QUERY` and `FBM_BOOK_ROW` instances carry `workspaceRef=FBM.BOOKS`. Consequently Wire UI Server v0.17 validates the full opaque event-time `workspaceContext`—query, scope, order, selection, result revisions and selected IDs—before dispatching a list action. A current rendered revision with a stale result context still fails closed.
## v0.6 browser row/action transport contract

The first-class row contract must survive the real browser transport. The server projects a hidden `FBM_WORKSPACE_CONTEXT@1` instance carrying the current `FBM.BOOKS` query/scope/order/selection/result revisions and selected IDs. Browser code may only echo this server-issued context; Wire UI Server v0.17 validates it and rejects stale or tampered values.

Every visible semantic row has a server-created `FBM_BOOK_OPEN@1` child action. The browser identifies the action instance it received, not a Merchant trade/book identifier of its own choosing. It must never send `rootTradeId`, row number, or visible position as action authority. The server resolves the stable `semanticRowId` from its own action instance and performs selection by identity.

Acceptance must exercise the actual `Queue Fabric -> Queue Fabric Web Gateway WebSocket -> Alchemy Wire UI BrowserRenderer` path and prove 0/1/N semantic rows remain independently addressable through that transport.

