# Wire UI Swing changelog

## v0.2-dev10 — 2026-10-03

- Consume accepted Wire UI Server v0.17 `windowOffset`, `windowLimit`, and `windowTotalCount` slots as authoritative virtual-viewport metadata.
- Preserve compact `rangeWindow={start,count,total}` compatibility; no new source-authority protocol is introduced.
- Clamp the renderer extent for a valid final partial window without rewriting the server's authoritative requested limit.
- Add strict Java coverage for direct Server v0.17 metadata and the 200,000-row final-window edge.
- Add real ooRexx/BSF integration coverage for `RangeRequested -> application/server reconcileCollectionWindow -> authoritative replacement patch`, including the final partial window.

# Changelog

## v0.2-dev8 — 2026-09-28

- Connect server-projected `rangeWindow={start,count,total}` metadata to a renderer-private proportional Swing virtual scrollbar.
- Native scrollbar drag and mouse-wheel movement emit semantic `RangeRequested(start,count)` through the existing event-time action boundary.
- Keep only the authoritative resident `items` window in the JList; viewport movement never traverses source/backing storage or replaces rows locally.
- Suppress demand echo while authoritative range metadata is being applied.
- Preserve stable Wire element identity and capture `renderedRevision` at demand time.
- Add strict regression coverage for a 200,000-row virtual extent and authoritative subsequent window replacement.
- Strict Java suite: 56/56.


## v0.2-dev7 — 2026-09-27

- Add renderer-neutral bounded collection demand `requestRange(elementInstance,start,count)`.
- Emit `RangeRequested` through the normal event-time UI_ACTION authority boundary.
- Preserve resident Swing list/model state until authoritative application/server projection arrives.
- Fail invalid bounded demand closed as `RANGE_REQUEST_INVALID/ACTION`.
- Add strict regression locks for event-time revision and no local projection mutation.


## v0.2-dev7 — 2026-08-28

Recovered and sealed continuation of the v0.2 line. The prior dev6 workstream had reached structural collection support but was intentionally left unsealed when its build environment disappeared.

- Restores the dev5 exact-definition authority/cache contract: inline render-profile manifests, proactive cold definition requests, immutable non-pruning cache, warm reauthorisation, manifest-id reuse protection, exact content-address checks, and action blocking/resync on committed-view deauthorisation.
- Restores first-class `UI_MATERIAL_SET` exact identity and conservative material-token presentation; release provenance is not immutable material content.
- Restores browser-parity typed field presentation while keeping wire values strings.
- Restores local-only collection selection, explicit activation, stable server-identity selection across reorder, and narrow action detail.
- Retains/qualifies dev6 structural operations: `CREATE_INSTANCE`, `SET_SLOT`, `LIST_APPEND`, `LIST_MOVE`, `DESTROY_INSTANCE`, `LIST_REMOVE` with explicit server child order, transaction preflight, identity-preserving moves, and descendants-first removal.
- Adds Wire UI Server v0.17 `workspaceContext` support. Workspace-bound actions capture and deep-freeze exact server-projected context at the same event-time boundary as `renderedRevision`; future fields and result-revision evidence pass through unchanged.
- Missing/mismatched workspace context fails closed. Swing selection cannot manufacture server `selectedIds`.
- Adds native Server v0.17 acceptance proving current context succeeds, queued pre-patch context remains unchanged and is rejected as stale by the server, and a later action succeeds with the new context.
- Updates Builder acceptance to v0.11 and Server collection-window acceptance to v0.17.
- Preserves focus and unsent editor state across structural relayout.
- Makes `WireSwingDesktopWindow.onClosed` exactly once for explicit or window-system closure.
- Strict Java suite: 52/52.

## v0.2-dev5 — recovered contract

The original dev5 package was not present in the supplied roll-up, so this delivery does not claim byte identity with it. The shared-workstream handover identified these accepted semantics, all of which are reconstructed and requalified in dev6: exact definition authority/cache behavior, local-only collection selection, material-set identity, typed fields, and desktop close callback.

## v0.2-dev3 — preserved supplied baseline

The supplied API roll-up contained `wire_ui_swing_v0.2-dev3.zip`. It remains the byte-level recovery base used together with the preserved workstream handover to reconstruct the missing later development.

## 0.2-dev10 — 2026-10-22
- Added a modern renderer-owned desktop material treatment while preserving WIRE-UI semantics.
- Added `--notnotes-demo` and `--notnotes-smoke` Java/Swing NotNotes presentation fixtures.
- Added denser collection/navigation styling, modern cards, typography, fields and primary actions.
- Preserved legacy standalone Search demo and the complete dev9 authority/virtualisation contracts.
- Strict renderer suite remains 58/58.
