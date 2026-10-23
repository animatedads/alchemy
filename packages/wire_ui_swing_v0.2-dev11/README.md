# Wire UI Swing v0.2-dev10

Defensive Java Swing renderer and desktop shell for `WIRE-UI/0.1`.

This cut is the recovered continuation of the v0.2 development line. It restores the dev5 authority/cache/material contracts, retains the dev6 structural collection operations, and completes the previously unsealed Server v0.17 `workspaceContext` boundary.

## Authority boundary

Swing owns rendering, stable component instances, local focus/selection/edit state, and renderer-local failure containment. It does **not** own business state, journey transitions, access permission, server selection truth, experiment assignment, release selection, or semantic action availability.

Swing listeners enqueue `UI_ACTION`; they never synchronously call ooRexx, Queue Fabric, JMS, network code, or application logic.

## Current protocol support

Inbound:

- `UI_RENDER_PROFILE`, including the exact authorised definition manifest projected inline by current Wire UI Server.
- `UI_DEFINITION_MANIFEST` and immutable exact `UI_DEFINITION` delivery.
- `UI_MATERIAL_SET` with exact `materialId@version` identity.
- `UI_VIEW_SNAPSHOT`.
- `UI_VIEW_PATCH` operations: `CREATE_INSTANCE`, `SET_SLOT`, `LIST_APPEND`, `LIST_MOVE`, `DESTROY_INSTANCE`, `LIST_REMOVE`.

Outbound:

- `UI_HELLO` renderer capabilities.
- proactive exact `UI_DEFINITION_REQUIRED` for cold authorised definitions.
- `UI_ACTION` with event-time `viewRef` / `renderedRevision`.
- scoped `UI_ERROR` and `UI_RESYNC_REQUEST` on fail-closed boundaries.

## Server v0.17 workspace actions

For an instance carrying `slots.workspaceRef`, a Swing action is emitted only when the same authoritative instance also carries a matching server-projected `slots.workspaceContext`.

At the instant of the Swing event the runtime:

1. captures the current `renderedRevision`;
2. deep-freezes the complete server-projected `workspaceContext`;
3. places that exact opaque context into `UI_ACTION.detail.workspaceContext`;
4. preserves unknown/future fields, including result revision evidence;
5. never derives or rewrites server `selectedIds` from local Swing selection.

If the context is missing or its `workspaceRef` mismatches the instance, the action fails closed locally. If the server advances after an action is queued, the queued action keeps its historical context and revision; Server v0.17 can then reject it as stale in the normal way.

## Definition authority/cache

- Exact `definitionId@version` + content address is immutable cache identity.
- An inline render profile manifest proactively requests only cold exact definitions.
- Manifest changes do not prune immutable cached definitions.
- Reauthorising an already cached exact definition is warm and causes no duplicate definition request.
- A new manifest that deauthorises a definition used by the committed view keeps the existing pixels for recovery, blocks semantic actions, emits `COMMITTED_VIEW_DEAUTHORISED`, and requests resynchronisation.
- `profileId` is delivery/authorisation context, not immutable definition content.
- manifest-id reuse with different contents, blank content addresses, profile mismatch, and cache/address conflict all fail closed.

## Collections and structural patches

Server child membership/order is explicit semantic state. `LIST_MOVE` reorders the existing Swing component rather than reconstructing it. Structural re-layout preserves surviving component identity, unsent editor contents, and focus. Destruction/removal is validated descendants-first before visual mutation.

Actionable collection highlighting is local-only. Selection produces no action by itself; activation is explicit (Enter or double-click), and action detail is limited to the recognised server row identity. Local selection never becomes server workspace-selection truth.

## Materials and fields

`UI_MATERIAL_SET` is cached by exact `materialId@version`; content address, tokens, and recipes are immutable while `siteRelease` remains provenance. A conservative token subset may influence Swing presentation without changing semantics.

Browser-parity field hints create suitable Swing editors (`date`, `number`, `email`, text), but semantic field values remain strings on the wire.

## Build and run

```bash
./scripts/run_tests.sh
./scripts/build.sh
java -jar build/wire-ui-swing-v0.2-dev10.jar --version
java -jar build/wire-ui-swing-v0.2-dev10.jar
```

Real-window tests require a graphics environment; the automated acceptance uses Xvfb.

The exact ooRexx/BSF4ooRexx and current Server/Builder acceptance commands are documented in `integration/BSF4OOREXX_NOTES.md` and `VALIDATION.txt`.

## dev7 — bounded renderer demand

`requestRange(elementInstance,start,count)` adds the shared virtual-collection demand seam. It emits semantic `UI_ACTION action=RangeRequested` through the existing event-time authority boundary. Swing does not traverse backing storage, fetch rows, or mutate the resident list in response; application/server authority decides whether and how to satisfy the request. Invalid ranges fail closed as `RANGE_REQUEST_INVALID/ACTION`.

This implements the bounded-demand rule from `wire_renderer_conformance_v0.2-dev2` without introducing Swing-specific source semantics.


## dev9 — Server v0.17 large-window round trip

dev9 closes the compatibility gap between Swing's compact `rangeWindow={start,count,total}` projection and the accepted Wire UI Server v0.17 large-collection contract. Server v0.17 already publishes authoritative `windowOffset`, `windowLimit`, and `windowTotalCount` slots from `WireUICollectionWindow`; Swing now consumes those slots directly as bounded viewport metadata without inventing a second server protocol.

The renderer still owns no source traversal. Native viewport movement emits `RangeRequested(start,count)` through the ordinary event-time `UI_ACTION` boundary. Application/server authority decides whether to satisfy that request, calls `reconcileCollectionWindow()`, and projects the replacement rows plus authoritative window metadata back to every renderer. A final partial window is valid: `offset=199950, limit=100, totalCount=200000` yields an effective 50-row renderer extent while retaining the server's requested limit semantics.

Qualification includes a real ooRexx 5.3.0 r13196 + BSF4ooRexx + Wire UI Server v0.17 round trip over a 200,000-message collection, including a replacement window and a final partial window.

## dev8 — native virtual viewport demand

A collection becomes virtual only when the authoritative projection supplies `rangeWindow` with `start`, `count`, and `total`. Swing then shows a renderer-private proportional scrollbar whose extent can represent a 200,000-row collection while the JList continues to hold only the currently projected bounded window. Dragging the virtual scrollbar or using the mouse wheel emits `RangeRequested(start,count)`; it does not fetch, filter, enumerate, or replace source rows. The application/server remains responsible for satisfying the demand with a later authoritative `items` + `rangeWindow` patch.

## dev10: modern desktop material + NotNotes Java presentation fixture

`--notnotes-demo` opens a renderer-only NotNotes composition using the same WIRE-UI/0.1 runtime. It demonstrates the intended Java visual quality without moving document, lifecycle, report or intention authority into Swing. dev10 adds a modern neutral material layer (quiet canvas, elevated cards, dense collection rows, stronger type hierarchy, modern buttons/fields and controlled spacing). The fixture uses stable semantic document identities and bounded collection metadata; it is presentation evidence, not a second NotNotes domain implementation.
