# Wire UI Swing v0.2-dev6

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
java -jar build/wire-ui-swing-v0.2-dev6.jar --version
java -jar build/wire-ui-swing-v0.2-dev6.jar
```

Real-window tests require a graphics environment; the automated acceptance uses Xvfb.

The exact ooRexx/BSF4ooRexx and current Server/Builder acceptance commands are documented in `integration/BSF4OOREXX_NOTES.md` and `VALIDATION.txt`.
