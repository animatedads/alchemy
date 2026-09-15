# FederationBank Merchant Wire UI Web v0.6

Early Merchant Banking operator UI over the sealed Merchant authorities, now with a real browser/Queue Fabric roundtrip for first-class semantic rows.

## Authority topology

```text
Merchant Bank v0.15       Merchant Risk Service v0.5       Merchant Accounting Adapter v0.5
        \                         |                                  /
         \________________________|_________________________________/
                                  |
                                  v
                 FBMerchantWireAuthorityProjectionAdapter
                                  |
                                  v
                    FBMerchantWireProjectionFeed
                                  |
                                  v
                     FBMerchantWireApplication
                                  |
                                  v
                         Wire UI Server v0.17
                                  |
                                  v
                     Queue Fabric / Web Gateway
                                  |
                                  v
                       Alchemy Wire UI JS
```

The browser is presentation/navigation only. It does not book trades, create close intent, approve or execute remediation, instruct or observe settlement, move collateral, post accounting, mutate Ledger or mutate Core Banking.

## First-class rows

`FBM.BOOKS` remains a server-owned 0/1/N semantic collection. Each visible book is a child `FBM_BOOK_ROW@1` instance with stable `semanticRowId=rootTradeId`. Paging changes only the visible window; row position has no authority meaning.

v0.6 adds a server-issued `FBM_BOOK_OPEN@1` child beneath each visible row. A browser activation sends the action element identity and event-time workspace context. It does **not** send `rootTradeId` as authority. The ooRexx application resolves the semantic row identity from the action instance it created, updates selection, and projects the dossier.

## Browser workspace context

Wire UI Server v0.17 requires the current query/scope/order/selection/result context for list actions. v0.6 projects that context in hidden `FBM_WORKSPACE_CONTEXT@1`. `MerchantWorkspaceContextEcho` observes server snapshots/patches and echoes the latest server-issued values on `UI_ACTION`.

The echoed values are optimistic concurrency evidence only. Wire UI Server still compares them to its current authoritative context and rejects stale/tampered commands.

## Exact release

```text
FEDERATIONBANK_MERCHANT_OPERATIONS@2026.09.01.1
semantic/federationbank_merchant_operations_v0.6.json
```

The release contains 12 definitions. Builder v0.11 is authoring/qualification-time only; runtime loads the precompiled package.

Current semantic actions remain read/navigation only:

```text
WORKSPACE.REFRESH
BOOKS.FILTER
BOOKS.SORT
BOOKS.WINDOW
BOOKS.SELECT
BOOK.OPEN
```

## Real transport qualification

The packaged acceptance includes a real browser-runtime path:

```text
ooRexx application
 -> Wire UI Server v0.17
 -> Queue Fabric v0.9-dev4
 -> Queue Fabric Web Gateway v0.2 WebSocket edge
 -> Alchemy Wire UI JS v0.4-dev4 BrowserRenderer
```

It renders three independent server-issued rows and activates `ROOT-A::OPEN`. The captured browser action contains no Merchant book ID in detail; the server selects `ROOT-A` from its own action-instance state and returns the selected dossier.

## Starter

Visual preview:

```bash
./start.sh
```

Thin live browser shell attached to an authoritative bootstrap:

```bash
./start.sh --live \
  --bootstrap-url http://127.0.0.1:8090/wire-ui/bootstrap \
  --wire-ui-js-root /path/to/alchemy_wire_ui_js_v0.4-dev4
```

`FBMerchantWireWebGatewayService` is the ooRexx-side fixed access-point seam for deployment through Queue Fabric Web Gateway v0.2. The package-root starter deliberately remains web-hosting/bootstrap plumbing rather than silently constructing Merchant business authorities.

See `docs/LIVE_BROWSER_ROW_CONTRACT.md`, `docs/LIVE_PROJECTION_APPLICATION.md`, and `docs/PROJECTION_REQUIREMENTS.md`.
