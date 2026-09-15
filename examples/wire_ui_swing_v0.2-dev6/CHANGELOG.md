# Changelog

## v0.2-dev6 — 2026-08-28

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
