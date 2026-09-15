# ooRexx Wire UI Server v0.17

Server-side authoritative Wire UI runtime for Alchemy.

v0.9 keeps the `WIRE-UI/0.1` semantic protocol and reconciles the two independently developed v0.8 lines: renderer-profile/definition-manifest negotiation and versioned material delivery. Earlier release-binding, journey, agent-profile, experiment and observation behavior remains intact.





v0.10 restores the dynamic journey/application seam required by long-lived Builder-authored applications such as FlyLo v0.3 while retaining every v0.9 reconciliation capability. `WireUIApplication~advanceJourney()` applies the authoritative transition/subscription plan and emits the updated manifest/journey; `createViewInstance()` permits only definitions authorised by the active plan and emits a revisioned `CREATE_INSTANCE` patch. `WIRE-UI/0.1` remains unchanged.



## v0.17 authoritative workspace result revision

Dense operational workspaces now distinguish the **query that was asked** from the **authoritative business result that answered it**. `WireUIWorkspaceResultState` records a monotonically increasing `resultRevision` together with the exact query/scope/order revisions that produced the result, authoritative total membership count, factual aggregates, provenance and optional as-of reference.

This matters when the filter and selected semantic identities remain unchanged while valuation, sanctions, collateral, margin or other authoritative state changes underneath the workspace. A bulk command is not allowed to inherit authority merely because its query text still matches.

`WireUIWorkspaceCommandContext` therefore carries the exact current result revision when one has been published. Query/sort movement makes the previous result explicitly non-current until the application publishes the corresponding refreshed result. Republishing business results under the same query advances only `resultRevision`; semantic selection is preserved, but an older command context is rejected.

The browser does not choose or certify `resultCurrent`. The server recomputes currentness from the authoritative query/result objects and validates the exact result revision before semantic dispatch. The result object contains factual aggregates only; downstream risk/commercial/legal interpretation remains outside Wire UI.

A real ooRexx <-> Alchemy Wire UI JS v0.4-dev4 acceptance proves the expanded command context crosses the existing `UI_ACTION.detail.workspaceContext` seam unchanged. `WIRE-UI/0.1` remains unchanged.

## v0.16 authoritative workspace query, selection and command context

Dense operational workspaces now have explicit server-owned query and selection state instead of relying on hidden renderer/table state. `WireUIWorkspaceQueryState` tracks semantic filters and sort order using separate monotonic `queryRevision`, `scopeRevision` and `orderRevision` values. Filter changes advance membership scope; sort changes advance ordering without invalidating semantic selection.

`WireUIWorkspaceSelection` records selected semantic identities independently of the currently materialised collection window. A scope-changing filter invalidates the previous selection by default, preventing a stale bulk command from acting on rows that no longer belong to the authoritative workspace query. Re-sorting preserves selection because semantic identity has not changed.

`WireUIWorkspaceCommandContext` freezes the exact query/scope/order/selection revisions plus selected semantic identities for a command. An element opts into this guard by carrying a semantic `workspaceRef` slot. The normal `UI_ACTION.detail.workspaceContext` must then match the server's current context before dispatch. A current view revision alone is not enough to authorise a bulk/workspace command whose query or selection context has drifted.

The browser remains free to render filters, table headings and selection affordances, but those controls do not become authoritative business-query state merely because they are visible. The server validates the resulting semantic context before dispatching operations such as bulk close, transfer, review or acknowledgement.

A real ooRexx <-> Alchemy Wire UI JS v0.4-dev4 acceptance proves the server-authored context survives the JavaScript semantic-action seam unchanged and is accepted on return. `WIRE-UI/0.1` remains unchanged; the context is carried in the existing `UI_ACTION.detail` structure.

## v0.15 large collection windows and evidence streams

Dense operational workspaces may project a small visible window over a very large authoritative collection. `WireUICollectionWindow` records the server-owned window coordinates (`offset`, `limit`, `totalCount`), explicit sort/filter references, anchor and window revision without pretending the browser owns the full book.

`WireUIView~reconcileCollectionWindow()` accepts the exact ordered rows for that window and emits the smallest supported `WIRE-UI/0.1` structural delta using existing `LIST_APPEND`, `LIST_MOVE`, `LIST_REMOVE`, `DESTROY_INSTANCE` and `SET_SLOT` operations. Row membership/order, row slot changes and the collection's window metadata are committed under one view revision. A repeated identical window is a no-op. Stable row identities keep their exact compiled definition key; a retained identity cannot silently change from (for example) `POSITION_ROW@1` to `POSITION_ROW@2`.

This is intended for cases such as a 50-row trader viewport over tens of thousands of authoritative positions. Only the visible window need exist in renderer state; `windowTotalCount` remains an authoritative semantic fact and is distinct from the number of materialised child instances. Sort/filter references describe the server-selected view of the collection and do not grant the browser authority to reorder business truth.

`WireUIEvidenceEntry` provides a factual, attributable event shape for append-only operational evidence timelines. Entries carry stable event identity, event type, occurrence time, severity, source, provenance and correlation plus bounded attributes. `appendEvidence()` projects those facts with ordinary semantic collection operations. Wire UI still does not infer conclusions such as manipulation, policy breach or customer frustration; assessment belongs downstream.

A real ooRexx -> Alchemy Wire UI JS v0.4-dev4 acceptance proves window replacement across the existing adapter: one row is retained and updated in place, one leaves the renderer window, one arrives, ordering remains authoritative and the JS runtime receives the advanced window metadata.

## v0.14 operational intent and cross-object projection

v0.14 extends the dense-workspace path with `WireUIIntentProjection`, a server-authored semantic representation of a proposed action and its currently projected consequences, warnings, admissible actions and required confirmations. It is deliberately presentation evidence rather than transaction authority.

`WireUIView~setSlotsAcross()` can update several semantic instances under one monotonically increasing view revision. `WireUIProjection~bindDerived()` / `projectDerivedGroup()` and `WireUIApplication~mutateStateGroup()` let legal, risk, position, collateral or other authoritative object state be recomputed against one complete state snapshot and exposed coherently without transient impossible combinations.

The FederationBank-style acceptance proves a close-position intent in which legal transfer restrictions, collateral availability and position value jointly determine position state, risk severity, margin shortfall and whether confirmation is currently admissible. The browser does not derive reversal direction, net effect, warnings or permission to confirm.


## v0.13 operational workspace projection

v0.13 grows the server from journey/forms-oriented projection into dense professional operational workspaces without changing `WIRE-UI/0.1`. The FederationBank Merchant Banking workspace is the capability driver; it is not a runtime dependency.

`WireUIView` now owns stable ordered collection membership and emits the protocol operations already implemented by the browser runtime: `LIST_APPEND`, `LIST_MOVE` and `LIST_REMOVE`. Row identities are semantic instance identities, not DOM positions. Reordering a position therefore changes authoritative collection order instead of destroying/recreating the portfolio. Removing a row also clears any owned semantic descendants and associated stale action history.

`setSlots()` applies a group of slot changes under one revision. This is important for operational truth such as a legal/custody event changing `economicState`, `severity`, `riskSummary` and `replacementExposure` together: the renderer must never momentarily display a mixture of old and new risk truth because four independent revisions happened to arrive separately. `WireUIProjection~bindSlots()` provides the dependency-indexed projection seam for such grouped state.

`WireUISemanticState` provides typed authoritative state meaning (`kind`, `code`, `displayValue`, optional severity/unit/semantic role/provenance). It deliberately does not encode CSS classes or browser styling. A compiled renderer definition may choose how to expose those semantic facets; machine-semantic projections may consume the same meaning without a visual treatment.

The mandatory cross-language acceptance now drives an ooRexx-authored Merchant-style position collection through Alchemy Wire UI JS v0.4-dev4, proving append, grouped row mutation, move and remove across the real server semantic adapter.

## v0.12 factual journey timing evidence

v0.12 adds a server-side factual timing ledger without changing `WIRE-UI/0.1`. It is deliberately not a browser analytics engine and it does not label an interaction as slow, frustrating, manipulative, successful or commercially valuable.

`WireUIApplication` now records server-authored timing evidence around semantic actions and journey movement. A validated semantic action produces `SEMANTIC_ACTION_VALIDATED`; a successful dispatch produces `SEMANTIC_ACTION_COMPLETED`; successful `advanceJourney()` records `JOURNEY_STATE_ENTERED`. Application/business code may add factual milestones such as `OFFERS_AVAILABLE` through `recordJourneyTiming()`. Accepted client observation messages create a separate `CLIENT_OBSERVATION_ACCEPTED` server-receipt timing fact while retaining the original authorised observation record.

Each `WireUIJourneyTimingRecord` carries application identity, current journey state/revision, transition reference, view/revision, correlation id, server clock reading, optional wall stamp, exact site-release provenance and a server-authored detail table. Timing records stay server-side by default: they are not silently inserted into snapshots or sent to the browser. `drainJourneyTimings()` provides an explicit handoff to Interaction Event / evidence / benchmark consumers.

The clock is injectable through `setTimingClock()`, allowing deterministic acceptance tests and avoiding hidden test sleeps. `elapsedMicrosSince()` computes only a factual same-application interval and rejects reversed/invalid clocks; interpretation belongs downstream. Duplicate direct-queue actions do not manufacture duplicate timing evidence, and rejected/stale actions are not labelled as validated or completed.

This supports airline-journey benchmarking such as SEARCH action accepted -> offers available -> journey entered -> browser presentation observation while preserving the existing separation between server truth and authorised client observations.


## v0.11 multiple bound semantic actions

v0.11 adds a backwards-compatible instance action list for authoring surfaces that legitimately expose more than one semantic action. `slots.action` remains the legacy primary action; optional `slots.actions` may list additional actions. Every action still requires an explicit `WireUIView~setActionAvailable()` record at the rendered revision and passes the existing ownership, revision and security-policy checks.

This closes the generic platform seam required by Wire UI Builder v0.4: one composition canvas can support both `COMPOSITION.SELECT` and `DESIGN.COMPOSITION.MOVE` without weakening action validation or encoding a move as an unrelated click action. `WIRE-UI/0.1` is unchanged.

## v0.10 dynamic journey runtime

- `advanceJourney(state, trigger, evidence)` records the server-owned transition, differentially reconciles ACTIVE/PREFETCH/ON_DEMAND subscriptions, refreshes the authorised definition manifest when a render profile is selected, and emits the canonical journey plan.
- `createViewInstance(instanceId, definitionKey, slots, parentId)` refuses unregistered or currently unauthorised definitions.
- `WireUIView~createInstancePatch()` creates the instance and advances the authoritative view revision with an exact `CREATE_INSTANCE` operation.
- Cold-cache browser runtimes are expected to hold such patches behind the immutable-definition barrier implemented by Alchemy Wire UI JS v0.4-dev4.


## v0.9 collision reconciliation

v0.9 reconciles two independently developed v0.8 lines that had acquired the same package version.
It preserves both capabilities instead of choosing one branch:

- server-authoritative renderer-profile negotiation and exact authorised definition manifests/cache-miss validation;
- versioned Builder material-set delivery (`UI_MATERIAL_SET`) with exact site-release provenance;
- deterministic parent-before-child snapshots;
- the existing release/journey/experiment/observation runtime contracts.

The protocol generation remains `WIRE-UI/0.1`; the merge is additive. Published runtime references remain exact and version-qualified.
The historical `wire_ui_queue_gateway_v0.1-dev1` integration fixture is retained as an optional compatibility test; current browser-gateway validation is performed separately against the current Queue Fabric Web Gateway line.

## v0.8 renderer-profile bootstrap and definition cache negotiation

v0.8 closes the server side of the Queue Fabric gateway/browser bootstrap without moving application semantics into the gateway. `UI_HELLO` now selects a server-authoritative renderer capability profile independently of the semantic interaction profile (`HUMAN_VISUAL` / `AI_AGENT_OPTIMISED`).

The server derives an exact `WireUIDefinitionManifest` from the definitions reachable through the application's currently active authorised subscriptions. The manifest contains only exact `(definition id, version, contentAddress)` references. The browser may use its immutable cache and request only misses with `UI_DEFINITION_REQUIRED`. Every request is revalidated against the current manifest; a client cannot name an inactive ON_DEMAND definition to probe the catalogue.

`WireUIRenderProfilePolicy` maps a capability fingerprint, or conservative coarse capability facts such as viewport/pointer class, onto a named renderer profile. Browser capability claims select among server-defined renderer profiles; they do not select arbitrary executable code or change business authority.

A manifest change is deterministic. Explicit ON_DEMAND activation or another authoritative subscription change produces a new manifest identity. Stale-manifest definition requests are rejected. Queue Fabric delivery reliability means repeated requests for a definition already queued for the same manifest do not create duplicate definition payloads.

v0.8 also fixes a live integration defect exposed by the real gateway acceptance: `WireUIView~snapshot` is now deterministically parent-before-child. A snapshot can therefore be reconstructed by a direct renderer without depending on ooRexx table iteration order.

The mandatory integration fixture now runs a real `WireUIApplication` in ooRexx through real Queue Fabric, the unmodified `wire_ui_queue_gateway_v0.1-dev1`, and `alchemy_wire_ui_js_v0.4-dev1`. A cold runtime receives the manifest, requests exact cache misses, renders FlyLo semantic state, sends `ASSISTANT.OPEN`, and receives the resulting authoritative patch. A fresh runtime reconnecting with the same content-addressed definition cache reconstructs the current view with **zero definition requests**.

A headless-Chromium wrapper fixture is included as an external acceptance. In the present validation container Chromium fails to establish the gateway WebSocket even against the gateway package's own stock browser fixture, while the gateway's real Node WebSocket/Queue Fabric tests are green; therefore Chromium is not part of the mandatory v0.8 validation transcript.

## v0.7 authorised observation runtime

Wire UI observation subscriptions are now executable rather than latent metadata. `WireUIObservationDefinition` defines an immutable positive-list observation point with exact version, authorised purpose, allowed payload fields and declared evidence strength.

Activating a subscription that contains observation definitions emits the existing JS-compatible `OBSERVATION_PLAN`. The browser may only report points/fields offered by that plan. Incoming `INTERACTION_OBSERVATION` messages are revalidated against the active subscription, exact subscription revision, point, purpose, evidence strength and field allow-list before becoming a `WireUIObservationRecord`.

Accepted records are factual evidence. Wire UI does not infer analytics, dark-pattern findings, brand effect or design conclusions. Those belong to downstream assessment/effect layers. Duplicate direct-queue messages do not duplicate accepted evidence.

The server stamps current application/release provenance itself; browser-supplied release provenance is optional and, when present, must match. `drainObservations()` provides a runtime-neutral hand-off seam for a later Interaction Event/evidence sink without adding another transport.

A real ooRexx ↔ JS v0.4-dev1 acceptance proves the current JS `ObservationPlan` and the server positive-list validator agree on the wire, including the JS fast-return for disabled points and allowed-field projection.

## v0.6 compiled experiment runtime

v0.6 consumes Builder-compiled element experiments without making the browser authoritative for experiment choice. `WireUIExperimentAssignment` binds an experiment and variant to one exact compiled `definitionKey` and the exact sealed site release.

Assignments are made server-side through `WireUIApplication~assignExperiment()`. The catalogue validates that the experiment and variant exist and that the selected projection resolves to an exact definition for the current interaction profile. ACTIVE/PREFETCH/ON_DEMAND subscription materialisation then substitutes that exact definition. Non-selected variants cease to be active delivery requirements.

The assignment subject is retained only as PRIVATE server state. It is deliberately omitted from `UI_JOURNEY_PLAN` and snapshot wire provenance; those messages carry experiment/variant/definition/release identity but not the user/session assignment key.

There is still no client message that grants itself an experiment variant. Assignment policy and bucketing remain server/application concerns.

## v0.5 release binding

`WireUICompiledCatalogue` consumes the public compiled-package contract produced by `wire_ui_builder_v0.1` and installs:

- exact version-qualified element definitions;
- Builder-provided definition content addresses verbatim;
- profile-specific compiled journey plans;
- release-managed ACTIVE/PREFETCH/ON_DEMAND subscriptions;
- HUMAN_VISUAL and AI_AGENT_OPTIMISED projections from the same sealed release.

`WireUISiteReleaseBinding` records four immutable coordinates for a running application:

- `releaseId`;
- exact release `version`;
- sealed site-release `contentAddress`;
- compiled-package `packageContentAddress`.

No runtime path resolves `latest`.

## Provenance

When an application is release-bound, the exact site release is attached to:

- `UI_JOURNEY_PLAN`;
- `UI_DEFINITION_REQUIRED`;
- authoritative application snapshots / resync snapshots;
- interaction-profile offers.

A browser/action may also echo `siteReleaseContentAddress`; if supplied, it must match the currently bound release or the action is rejected with `SITE_RELEASE_MISMATCH`.

## Profile switching

A normal semantic `INTERACTION.PROFILE.SELECT` action can switch a release-bound application to another profile compiled in the same release. The catalogue rebinds the server-owned journey/subscription plan while application/security authority remains unchanged.

For the OurLadyAir Builder fixture this means the same immutable release can move from:

`OLA_SEARCH_FORM@1` / `HUMAN_VISUAL`

to:

`OLA_SEARCH_STATE@1` / `AI_AGENT_OPTIMISED`

without introducing a separate bot API.

## Runtime boundary

Builder objects are authoring-time objects. The server consumes only the compiled package's public runtime-neutral contract. It does not need `WireUIDesignWorkspace`, mutable design graphs, or authoring logic in production.

Queue Fabric remains the transport substrate: direct queues carry live communications and topics carry definition-subscription delivery.
