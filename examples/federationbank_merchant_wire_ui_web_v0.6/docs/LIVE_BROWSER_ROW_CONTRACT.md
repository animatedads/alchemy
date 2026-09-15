# Merchant live browser row contract v0.6

`FBM.BOOKS` is a server-owned semantic collection. Browser position is never Merchant identity.

For each visible Merchant book the server issues:

```text
FBM_BOOK_ROW@1        instanceId = <rootTradeId>
  |
  +-- FBM_BOOK_OPEN@1 instanceId = <rootTradeId>::OPEN
```

The action child contains the server-owned `semanticRowId`. `BOOK.OPEN` does not accept a browser-supplied `rootTradeId`; the Merchant Wire application resolves the root identity from the server-issued action instance and then changes workspace selection by semantic identity.

## Workspace command context

Wire UI Server v0.17 requires list actions to carry the exact event-time workspace command context. The shared Alchemy Wire UI JS v0.4-dev4 runtime does not currently synthesise this context automatically, so Merchant v0.6 projects a hidden `FBM_WORKSPACE_CONTEXT@1` instance containing:

```text
workspaceRef
queryRevision
scopeRevision
orderRevision
selectionRevision
selectedIdsJson
resultRevision
resultQueryRevision
resultScopeRevision
resultOrderRevision
```

`MerchantWorkspaceContextEcho` observes only server-issued snapshots/patches and echoes the current context on outbound `UI_ACTION` messages. It does not decide whether the context is valid. Wire UI Server v0.17 compares every supplied field to its current authoritative state and fails closed on stale or tampered values.

This makes browser context an optimistic concurrency token, never authority.

## Transport qualification

The v0.6 acceptance crosses the real stack:

```text
ooRexx FBMerchantWireApplication
 -> Wire UI Server v0.17
 -> Queue Fabric v0.9-dev4
 -> Queue Fabric Web Gateway v0.2 WebSocket edge
 -> Alchemy Wire UI JS v0.4-dev4
 -> BrowserRenderer
```

Three server-issued book rows are rendered as independent instances. Activating `ROOT-A::OPEN` emits `BOOK.OPEN` with the server-issued element identity and workspace context, but no Merchant `rootTradeId` in browser detail. The ooRexx application resolves and selects `ROOT-A`, increments selection revision, and projects the selected-book dossier.
