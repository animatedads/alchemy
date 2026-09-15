# FederationBank Merchant Wire UI Web changelog

## v0.6 — live browser row authority

- advances the exact Builder release to `FEDERATIONBANK_MERCHANT_OPERATIONS@2026.09.01.1`;
- compiles 12 exact definitions, adding `FBM_WORKSPACE_CONTEXT@1` and `FBM_BOOK_OPEN@1`;
- keeps `FBM.BOOKS` as a structural 0/1/N child-row collection with stable `semanticRowId=rootTradeId` identity;
- adds a server-issued `BOOK.OPEN` action child beneath each visible row;
- removes browser `rootTradeId` from the open-book authority path: the server resolves identity from the action instance it created;
- projects the full Wire UI Server v0.17 query/scope/order/selection/result command context in one hidden semantic instance;
- adds `MerchantWorkspaceContextEcho`, which echoes only server-issued context and leaves all validation to Wire UI Server;
- proves the complete row action path over real Queue Fabric v0.9-dev4, Queue Fabric Web Gateway v0.2 WebSocket transport and Alchemy Wire UI JS v0.4-dev4 `BrowserRenderer`;
- adds `FBMerchantWireWebGatewayService`, a transport-only ooRexx seam that provisions the fixed Merchant browser access point and drains the application through Wire UI Server;
- preserves all v0.5 filtering/sorting/windowing/selection/result revision invariants;
- adds no trade, close, remediation, settlement, collateral, accounting, Ledger or Core Banking mutation action.

## v0.5

First-class stable row identity, explicit collection/window counts, bounded paging and independent query/scope/order/selection/result revisions.

## v0.4

Real Merchant Bank / Risk Service / Accounting authority projection adapter with live refresh.

## v0.3

First Builder-compiled and Wire UI Server-bound Merchant semantic release.

## v0.2

Early view-first Merchant operator workspace.
