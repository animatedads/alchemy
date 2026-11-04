# Wire UI Code Examiner integration

The Code Examiner is a Wire UI application surface over `SemanticSourceCodeExaminerWireApplication`.

## Authority topology

```text
Human browser
  -> Wire UI JS renderer
  -> Queue Fabric transport
  -> WireUIServer
  -> SemanticSourceCodeExaminerWireApplication
  -> semantic-source MCP/source authority
  -> NoSQLServer semantic source store
```

The browser owns only ephemeral presentation state. It never receives database authority and does not infer code acceptance.

## Suggested human layout

- left: search/results and ticket/work-entry navigator;
- centre: exact code revision with line numbers and accepted/candidate identity;
- right: attached design document and active findings;
- lower activity bar: Mark Error, Resolve Finding, Request Build, Request Test, Accept Work, Refuse Work, Refresh.

All controls emit the semantic actions documented in `MCP_COMMANDS.md`.

## Review invariant

The code pane, design pane, findings and test evidence must identify the exact semantic object/revision currently under review. A package build records the exact dependency revisions resolved at build time. A later dependency acceptance must not silently change the package already under review.

## Human browser package

`web/` is the browser access point for the examiner. It is intentionally not a
JavaScript code-review application. `bootstrap.mjs` connects the standard Wire
UI runtime and the CSS only decorates server-projected semantic roles.

Copy `web/config.example.mjs` to `web/config.mjs` and fill in the exact
WebSocket gateway URL and Wire UI inbound queue produced by the server host.
The browser refuses to fabricate local review data when the real Wire UI path
is unavailable.

The intended desktop arrangement is:

```text
+-------------------+--------------------------------+----------------------+\n
| Search / tickets  | exact code revision            | design / findings    |\n
| / work entries    | with visible revision identity | / test evidence      |\n
+-------------------+--------------------------------+----------------------+\n
| Mark error | Resolve | Request build | Request test | Accept | Refuse      |\n
+-------------------------------------------------------------------------+\n
```

`wire/CODE_EXAMINER_UI_DESIGN.json` records the human interaction design and
semantic action binding for the Wire UI Builder/compiler. It is design input,
not an alternative browser authority.

## Branch review

The human examiner exposes semantic actions `BRANCH.CLASSIFY`, `BRANCH.PROTECT`, `BRANCH.PACKAGE.REQUEST` and `BRANCH.CONFLICT.RESOLVE`. Branch warnings are part of module context and must not be hidden by the renderer.

## Semantic graph navigation (dev11)

The CODE region may emit reference-selection events for semantic graph edges. Navigation remains server authoritative through `CODE.GOTO_DEFINITION`, `CODE.FIND_USES`, `CODE.CALLERS`, `CODE.CALLEES` and `CODE.REFERENCE.EXPLAIN`. The browser must display the server-provided resolution state and must not infer a target for dynamic or unresolved references.

### Runtime class surface

For ooRexx classes the Examiner can request a captured effective class surface. This presents direct parents, inherited methods, local declarations, overrides and shadowed parent definitions, separately for instance and class methods. Runtime-derived edges remain provenance-stamped evidence and do not replace the source declaration graph.

## dev13 maintainability invariant

Wire UI is a projection of server semantic state, not an inventory maintained in HTML. No `<option>` list of source paths is permitted. A new module/source unit appears because the semantic authority catalog contains it.

`CODE.OPEN` has a complete-context contract. The authority must return exact revision identity and all agreed review facets (history, requirements, notes, resources, module/deployment/branch context, graph references, runtime surfaces, tests/work, exports/dependencies). This is intentionally fail-closed so feature loss cannot be hidden by a partially populated UI.

## Condensed class inspection default

The default class selection view is `CODE.CLASS.INSPECT`. It is deliberately token-efficient and does not include method bodies. The authority returns `semantic-source.class-inspection/1` containing the class hierarchy, an optional `since` cursor, `as_of`, and compact effective method rows. Each method row contains exact spelling, defining class (`from`), exposed state, and a return descriptor including the returned class/type when established. Full source, runtime surfaces and override evidence remain drill-down actions.

A caller that already inspected a class SHOULD pass the prior `as_of` value as `since`; the authority may then return only semantic changes since that point while preserving the class identity/tree context.

## dev18 deployment/security boundary

Wire actions enter through `SemanticSourceWireActionAdapter`, which requires a server-resolved opaque access token in security context. Browser-supplied identity is non-authoritative. `SemanticSourceSecureExaminer` resolves the verified principal, re-runs permission checks per semantic action, and requires fresh action-bound step-up for work disposition and protected branch mutation.

A normal production browser deployment receives transport coordinates from same-origin `service-descriptor`; it must not edit JavaScript to select queues or identities. The descriptor must declare `verified-session` principal authority and `opaque-bearer` session authority.
