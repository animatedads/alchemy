# Wire UI Swing v0.2-dev6 design contract

## 1. Authority

The renderer is deliberately subordinate to the Wire UI server. Swing owns only presentation instances and ephemeral local interaction state. It never infers journey, business, security, workspace membership, result currency, or action authority.

## 2. Transactional rendering

Snapshots and patches are parsed and validated against a semantic mirror before visual mutation. Patch preflight checks revision continuity, view identity, operation shape, structural membership, parent/child constraints, and exact definition availability. A failed preflight retains the previously committed visual tree.

Supported structural operations are `CREATE_INSTANCE`, `SET_SLOT`, `LIST_APPEND`, `LIST_MOVE`, `DESTROY_INSTANCE`, and `LIST_REMOVE`. Ordered children are semantic model state. Surviving bindings are re-laid out using their existing `JComponent` identities.

## 3. Exact definition authority

The active manifest authorises exact definition keys and content addresses. The immutable cache is not the same thing as current authority: deauthorisation does not erase cached bytes, but it can block actions from a committed view until authoritative recovery/resynchronisation occurs.

An inline `UI_RENDER_PROFILE` manifest is treated as the current server authority projection. Cold definitions are requested proactively. Reauthorised cached definitions are reused without a new request.

## 4. Event-time actions

A Swing listener captures local editor/activation detail and submits it only to the renderer action queue. The queue operation atomically stamps current application/session/access-point identity, view reference, and rendered revision.

For workspace-bound instances, the same critical section reads the current instance and exact server `workspaceContext`. The context is copied recursively and frozen as opaque evidence. Swing may not manufacture, merge from UI selection, normalise away, or otherwise reinterpret fields inside it. Renderer-generated local detail remains separate from this server context.

This gives two useful properties simultaneously:

- a queued action is immutable historical evidence of what the user acted against;
- a later incoming patch cannot make that queued action appear current.

## 5. Workspace fail-closed rule

If `slots.workspaceRef` is nonblank, `slots.workspaceContext` is mandatory and must carry the same `workspaceRef`. Missing/mismatched context emits a renderer error and no `UI_ACTION` is queued.

The server remains responsible for checking query/scope/order/selection/result revisions, exact selected IDs, result currency, and current view revision. Swing only transports the server projection unchanged.

## 6. Collections

Collection display selection is renderer-local. A selection change does not emit a semantic action. Explicit activation is Enter or double-click. Recognised stable row identities are preserved across server reorder and dropped if the server row disappears.

Server structural child order and collection display-item slots are distinct mechanisms; the renderer does not synthesize one authority source from the other.

## 7. Materials/presentation

Material identity is exact `materialId@version`. Content address, tokens, and recipes are immutable. `siteRelease` is provenance and can vary without redefining material content.

Presentation roles/tokens may alter appearance only. They cannot alter semantic action, identity, permissions, server values, or journey transitions.

## 8. EDT and lifecycle

All Swing construction/mutation is marshalled to the EDT. Structural re-layout preserves surviving editor focus when possible and retains local unsent text because the same component object survives.

`WireSwingDesktopWindow.onClosed` has exactly-once semantics whether closure comes from explicit `close()` or the window system.

## 9. Failure scopes

- `PROPERTY`: contain a slot/presentation failure at one component.
- `COMPONENT`: reject/placeholder unsupported or invalid exact component definition.
- `SUBTREE`: abort an unsafe structural proposal and keep the committed tree.
- `PATCH`: reject revision/operation failures and request resync where appropriate.
- `WINDOW`: desktop shell lifecycle boundary.
- `PROCESS`: not used for ordinary Wire/rendering faults.

## 10. Standalone demonstration

`WireSwingStandaloneDemo` is a separate miniature authority used only to exercise the executable JAR. It is not part of renderer authority. The runtime remains passive when connected to a real Wire UI server.
