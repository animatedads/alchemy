# Wire UI Swing sphere

## What this sphere preserves

This sphere is the project knowledge boundary for turning compiled Wire UI journeys into defensive Java Swing while preserving Wire UI authority separation.

The core architectural statement is:

```text
Wire UI Builder
    -> renderer-neutral semantic facts
    -> Wire UI Server / WIRE-UI/0.1
    -> exact renderer profile + definitions + materials + view state
    -> WireSwingRuntime semantic mirror
    -> preflight render plan
    -> EDT-confined JComponents
```

Swing is deliberately **not** a second application model. It owns component instances, local focus/selection/edit state before an action, renderer caches, presentation and local failure containment. It does not own journey transitions, business state, action permission, authentication, experiments or release selection.

## Important current compatibility facts

The 2026-08-28 19:19 roll-up contains the current Server/Builder line used for continuation:

- Wire UI Server v0.17
- Wire UI Builder v0.11
- Alchemy Wire UI JS v0.4-dev4
- Wire UI Swing v0.2-dev3

The historical roll-up copy is not the newest qualified Swing implementation. `wire_ui_swing_v0.2-dev10` is now the current source-qualified implementation baseline in this repository. It preserves the Server v0.17 authority/cache/workspace contracts, adds authoritative bounded virtual collection demand through `RangeRequested`, and adds the modern renderer-owned desktop material plus the NotNotes Java presentation fixture. Historical dev3/dev6 trees remain recovery evidence; new continuation should start from dev10.

Server v0.17 adds result-freshness evidence to the existing workspace command context seam. A Swing successor must preserve `UI_ACTION.detail.workspaceContext` as opaque server-projected event-time evidence, including `resultRevision`, `resultQueryRevision`, `resultScopeRevision`, `resultOrderRevision` and `resultCurrent`. It must not derive those facts—or `selectedIds`—from local Swing table/list state.

## Retrieval strategy

Start with:

- `ref.wire-ui-swing.architecture`
- `ref.wire-ui-swing.continuation`
- `ref.wire-ui-swing.workspace-context`
- `ref.wire-ui-swing.definition-manifest`
- `ops.wire-ui-swing.edt-action-boundary`

Searchable corpus aliases include `workspaceContext`, `resultRevision`, `GRID12`, `LIST_MOVE`, `BSF4ooRexx`, `sealed dev5`, `definition cache` and `UI_MATERIAL_SET`.

## Related sphere

The separate `java` sphere owns general Java/Swing language doctrine such as EDT discipline and transactional Swing rendering. This sphere intentionally specializes those principles for Wire UI protocol, Builder, Server, ooRexx/BSF and qualification continuity.


## Current implementation head — dev13

`packages/wire_ui_swing_v0.2-dev13` is the current source-qualified implementation baseline after merge to `main`. Dev13 is API-stable over dev12: it adds renderer-owned semantic-record section headings, projected status-chip treatment in detail cards and explicit empty-value placeholders. It does not change UI_ACTION detail, RangeRequested, workspaceContext, definitions/materials, deauthorisation or application authority.

Any future semantic/runtime API movement must be coordinated with the `wire-ui-runtime` lane before implementation.

Sealed dev13 SHA-256: `265137085793259c6442e5560eb771df5880a04bc8dd0f45559453eaea954b97`. Qualification: 63/63 strict renderer tests plus executable/JAR/Xvfb/desktop acceptance, fresh-unpack manifest verification and real NotNotes visual inspection.

## Source publication / autobuilder

Publish maintainable source, tests, scripts and qualification evidence through Git on `main`; autobuilder consumes that reviewed Git tree. Feature branches are staging only. Do not treat stale compiled JARs copied from older packages as source authority. Sealed ZIPs remain reproducibility/evidence artifacts, not the source-edit path.
