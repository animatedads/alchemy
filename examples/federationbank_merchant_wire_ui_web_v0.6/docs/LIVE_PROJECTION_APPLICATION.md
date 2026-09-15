# Live Merchant projection application

## v0.6 authority topology

```text
 Merchant Bank v0.15   Risk Service v0.5   Accounting Adapter v0.5
          \                 |                    /
           +-----------------+-------------------+
                             | exact reads
                             v
             FBMerchantWireAuthorityProjectionAdapter
                             | bounded scalars
                             v
                  FBMerchantWireProjectionFeed
                             |
                             v
                  FBMerchantWireApplication
       query / scope / order / selection / result revisions
                             |
                             v
                     Wire UI Server v0.17
                             |
                             v
                  generic browser / Swing renderer
```

The projection adapter validates that Risk Service references the exact projected Merchant Bank object and that Accounting Adapter belongs to the same Merchant legal entity. It does not create assessments, operational work, settlement evidence or accounting facts.

## Evidence-led discovery

Only customer-rooted CFD books already carrying an authoritative `MBCFDHedgeBookAssessment` are discoverable. Remediation/checkpoint/verification comes from Merchant Bank. Operational attention comes from Merchant state plus Risk Service work. Settlement is followed only through an obligation whose source execution can be bound to the selected portfolio. Accounting comes only from immutable Accounting Core entries correlated to that obligation.

## First-class semantic collection

`FBM.BOOKS` is a server-owned semantic collection. `book-table` owns the visible child row instances and a `WireUICollectionWindow`; it never stores an overloaded "rows-or-count" value.

Each row instance is keyed by stable Merchant `rootTradeId` and separately projects `semanticRowId`. The current child index is presentation only.

The server exposes explicit total and visible counts, bounded offset/limit, window revision and the v0.17 query/scope/order/selection/result revisions. `BOOKS.WINDOW` changes only which semantic rows are materialised; it does not change the underlying query result or selection.

Sorting changes `orderRevision` and preserves identity selection. Filtering changes `scopeRevision` and invalidates selection. If a selected row falls outside a later page/window, the row instance may disappear from the renderer while selected-book detail remains bound to the same semantic ID.

## Event-time workspace context

The application projects a hidden `FBM_WORKSPACE_CONTEXT@1` instance containing the server-issued `FBM.BOOKS` query, scope, order, selection and result revisions plus selected semantic IDs. `MerchantWorkspaceContextEcho` copies that current server-issued context onto outbound browser `UI_ACTION` messages. It does not calculate, author or validate any revision.

Both the query instance and semantic row/action instances carry `workspaceRef=FBM.BOOKS`. Wire UI Server v0.17 remains the authority that validates the echoed event-time `workspaceContext` before dispatch. A stale or tampered context therefore fails closed.

This matters independently of stale view revision checks: a list action can arrive from the current rendered view yet still refer to an older authoritative result. That action is rejected with a result-context mismatch rather than being applied to newer business facts.

Each visible semantic row has a server-created `FBM_BOOK_OPEN@1` child action. The browser sends the server-issued action instance ID (for example `ROOT-A::OPEN`) and current workspace context; it does **not** submit `rootTradeId`. The server resolves `semanticRowId` from its own action instance, updates semantic selection, and projects the selected dossier.

## Result revision independence

The application publishes a new whole-result revision when the query/order/scope result changes or the retained projection feed changes. Selection and window movement alone do not publish a new result revision. This preserves the distinction between "the user selected a different semantic object" and "the business result changed under the user".

## Explicit refresh

`FBMerchantWireAuthorityRuntimeFactory` supplies the authority adapter. Initial installation reads the authorities. `WORKSPACE.REFRESH` re-reads them before collection reconciliation. Filter/sort/window/select/open operate over the current bounded read projection and cannot create Merchant, Risk or Accounting evidence.

## Independent risk dimensions

Whole-book risk state and exact hedge evidence remain separate. A selected book may simultaneously be `DIRECTIONAL_RESIDUAL` while exact hedge evidence is `HEDGE_IMPAIRED`; renderers must not overwrite one with the other.

## Compiled interaction boundary

`semantic/federationbank_merchant_operations_v0.6.json` is the exact Builder v0.11 output consumed by Wire UI Server. Its site release is `FEDERATIONBANK_MERCHANT_OPERATIONS@2026.09.01.1`. Production runtime does not need mutable Builder authoring objects.

## No mutation authority

The adapter and application expose no trade booking, close, remediation approval/execution, settlement instruction/observation, collateral, accounting posting/reversal, Ledger or Core Banking mutation API. Browser role/profile is presentation context only and never substitutes for Access Control, exact object/method Permission or Security Effect.
