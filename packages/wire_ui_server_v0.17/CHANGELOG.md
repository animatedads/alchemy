# Changelog

## v0.17

- Added `WireUIWorkspaceResultState` for server-authoritative workspace result snapshots independently revisioned from filter/sort query state.
- Result snapshots bind exact query/scope/order revisions, authoritative `totalCount`, bounded aggregate facts, provenance and optional as-of reference.
- `WireUIWorkspaceCommandContext` now optionally binds the exact `resultRevision` and the query/scope/order revisions from which that result was produced.
- Commands are rejected with `WORKSPACE_RESULT_NOT_CURRENT` after query/sort movement until an authoritative result is republished.
- A refreshed business/risk result under an unchanged query invalidates older command contexts through `WORKSPACE_RESULT_REVISION_MISMATCH`.
- Result refresh does not clear semantic selection merely because valuation/risk state changed; command authority is nevertheless rebound to the new result revision.
- Extended the real ooRexx <-> Alchemy Wire UI JS v0.4-dev4 workspace-context acceptance to prove result-revision provenance survives the semantic-action seam.
- Expanded Alchemy STANDARD adoption coverage from 26 to 27 representative Wire UI object types.
- Rebased validation on Builder v0.9.1 and ooRexx Crypto v0.3 from `oorexxapis(20260828-132715).zip`.
- `WIRE-UI/0.1` remains unchanged.


## v0.16

- Added `WireUIWorkspaceQueryState` with independent query, membership-scope and order revisions for authoritative workspace filters/sorts.
- Added `WireUIWorkspaceSelection` using stable semantic identities independent of visible collection-window rows.
- Filter/scope changes invalidate stale selections by default; sort-only changes preserve selection.
- Added immutable `WireUIWorkspaceCommandContext` binding commands to exact query/scope/order/selection revisions and selected identities.
- `WireUIApplication` now supports workspace registration, filter/sort/selection mutation, context generation and context validation.
- Elements carrying `slots.workspaceRef` require an exact `UI_ACTION.detail.workspaceContext` before semantic dispatch; stale/forged/omitted workspace contexts are rejected.
- Added ooRexx acceptance for selection stability, scope invalidation and stale bulk-command rejection.
- Added real ooRexx <-> Alchemy Wire UI JS v0.4-dev4 acceptance proving workspace command context survives the JavaScript action/Queue adapter seam.
- Expanded Alchemy STANDARD adoption coverage from 23 to 26 representative object types.
- `WIRE-UI/0.1` remains unchanged.


## v0.15

- Added `WireUICollectionWindow` for authoritative large-collection windows with offset, limit, total count, sort/filter references, anchor and window revision.
- Added `WireUIView~reconcileCollectionWindow()` to compute create/update/move/remove deltas for the visible window and publish all membership, row and window-metadata changes under one view revision.
- Window reconciliation preserves stable instance identity, exact definition keys and server-owned ordering; rows outside the current window need not exist in renderer state.
- Identical windows are true no-ops with no revision churn; retained identities cannot silently switch compiled definition versions.
- Added `WireUIEvidenceEntry` and `appendEvidence()` for factual attributable operational evidence streams using ordinary semantic collection operations.
- Added real ooRexx -> Alchemy Wire UI JS v0.4-dev4 acceptance for a 2-row visible window over a declared 50,000-row collection.
- Expanded Alchemy STANDARD adoption coverage from 21 to 23 representative object types.
- `WIRE-UI/0.1` remains unchanged; the existing LIST_* and SET_SLOT vocabulary carries window reconciliation.


## v0.14

- Added `WireUIIntentProjection` for authoritative pre-action / pre-trade semantic consequence presentation.
- Added `WireUIView~setSlotsAcross()` for atomic multi-instance slot mutation under one view revision.
- Added cross-object derived projection bindings and `WireUIApplication~mutateStateGroup()` against a complete authoritative state snapshot.
- Added FederationBank-style intent/risk/collateral acceptance proving coherent derived workspace state.
- Extended ooRexx -> JS operational-workspace acceptance to a single multi-instance grouped patch.
- Kept `WIRE-UI/0.1` unchanged; existing `SET_SLOT` operations carry the richer coherent projection.


## v0.13

- Added authoritative ordered collection operations to `WireUIView`: `listAppend`, `listMove` and `listRemove`, emitting the existing `WIRE-UI/0.1` LIST_* patch vocabulary.
- Collection membership and ordering now live in server view state with stable instance identity; snapshots preserve that order parent-before-child.
- Collection-row removal recursively clears authoritative descendants and emits descendant `DESTROY_INSTANCE` operations before `LIST_REMOVE`, preventing renderer instance-registry leaks.
- Removed stale action-availability/history entries when an instance subtree is destroyed.
- Added `WireUIView~setSlots()` for atomic multi-slot mutation under a single view revision, suitable for risk/status/margin changes that must not expose impossible intermediate states.
- Added `WireUIProjection~bindSlots()` so one authoritative state dependency can project an atomic slot group rather than a single slot.
- Added immutable `WireUISemanticState` for typed semantic status/state meaning (`kind`, `code`, display value, severity, unit, semantic role and provenance) without prescribing DOM/CSS rendering.
- Added FederationBank Merchant-style operational-workspace acceptance covering stable position rows, row reordering/removal, grouped risk reassessment and typed semantic state.
- Added real ooRexx -> Alchemy Wire UI JS v0.4-dev4 cross-language acceptance for LIST_APPEND / grouped SET_SLOT / LIST_MOVE / LIST_REMOVE.
- Alchemy STANDARD adoption coverage increases from 19 to 20 representative object types.
- `WIRE-UI/0.1` remains unchanged.

## v0.12

- Added `WireUITimingClock` with injectable server timing source.
- Added immutable `WireUIJourneyTimingRecord` factual evidence with correlation, journey/view revision and release provenance.
- Added `WireUIApplication~recordJourneyTiming`, `journeyTimingRecords`, `drainJourneyTimings` and `setTimingClock`.
- Validated semantic actions now record `SEMANTIC_ACTION_VALIDATED`; successful dispatch records `SEMANTIC_ACTION_COMPLETED`.
- Successful journey advancement records `JOURNEY_STATE_ENTERED`; business/application code can record factual milestones such as `OFFERS_AVAILABLE`.
- Accepted authorised client observations add a separate server receipt timing fact without changing the observation evidence.
- Duplicate queue delivery does not duplicate timing evidence; stale/rejected actions do not create accepted-action timing records.
- Timing evidence remains server-side by default and is not injected into UI snapshots.
- Added deterministic journey-timing acceptance with injected clock and factual interval calculation.
- Alchemy STANDARD adoption coverage increases from 17 to 19 representative object types.
- `WIRE-UI/0.1` is unchanged.


## v0.11

- Adds backwards-compatible multi-action instance binding: legacy `slots.action` plus optional `slots.actions`.
- Preserves action availability-at-revision, stale-action, ownership and security-policy enforcement for every bound action.
- Adds `test_multi_action_binding.rex`, covering a legacy primary action, an additional bound action, and rejection of an unbound action.
- Advances Alchemy package identity to `0.11`; `WIRE-UI/0.1` remains unchanged.
- Validated with independent Wire UI Builder v0.4 visual composition authoring.

## v0.10

- Restores the dynamic application-journey API expected by FlyLo v0.3: `WireUIApplication~advanceJourney()` and `createViewInstance()`.
- Adds revisioned `WireUIView~createInstancePatch()` / `CREATE_INSTANCE` emission.
- Dynamic instances are accepted only when their exact definition is registered and authorised by the current active subscription plan.
- Adds mandatory `test_dynamic_journey_runtime.rex` covering transition evidence, subscription reconciliation, authorisation rejection, exact definition identity and revisioned patch emission.
- Validated with Alchemy Wire UI JS v0.4-dev4 and Queue Fabric Web Gateway v0.2.
- Retains all v0.9 renderer-manifest/material reconciliation behaviour; `WIRE-UI/0.1` is unchanged.


## v0.9

- Reconciles the two colliding `wire_ui_server_v0.8` development lines without dropping either feature set.
- Retains server-authoritative `UI_HELLO` renderer-profile negotiation, exact `WireUIDefinitionManifest`, strict cache-miss validation, stale-manifest rejection, and parent-before-child snapshots.
- Retains `UI_MATERIAL_SET`, exact Builder material tokens/recipe identifiers, release provenance, `WireUIApplication~materialSetMessages()`, and `WireUIServer~enqueueMaterialsToAccessPoint()`.
- Runs both renderer-profile/cache and material-delivery acceptance in the mandatory server suite.
- Rebased mandatory dependencies on Alchemy Objects v0.8, Queue Fabric v0.9-dev4, Builder v0.2, and the configured Alchemy Wire UI JS runtime.
- Keeps the older `wire_ui_queue_gateway_v0.1-dev1` full-session fixture as optional compatibility coverage rather than a mandatory runtime dependency.
- `WIRE-UI/0.1` remains unchanged; v0.9 is an additive package-version reconciliation.

## v0.8

- Added server-authoritative `UI_HELLO` renderer capability-profile negotiation.
- Added `WireUIRenderProfilePolicy`; renderer capability profile is kept distinct from HUMAN_VISUAL / AI_AGENT_OPTIMISED interaction profile.
- Added deterministic `WireUIDefinitionManifest` over the exact definitions reachable through active authorised subscriptions.
- Added `UI_RENDER_PROFILE` and `UI_DEFINITION_MANIFEST` server messages compatible with Alchemy Wire UI JS v0.4-dev1.
- Added strict `UI_DEFINITION_REQUIRED` validation against current manifest/profile/content address; inactive ON_DEMAND definitions cannot be fetched by name.
- Added duplicate definition-delivery suppression per exact manifest while retaining Queue Fabric delivery reliability.
- Manifest identity now changes when authoritative subscription/ON_DEMAND state changes; stale-manifest requests are rejected.
- Fixed `WireUIView~snapshot` to emit parent-before-child deterministic instance ordering.
- Added real ooRexx WireUIApplication <-> Queue Fabric <-> wire_ui_queue_gateway_v0.1-dev1 <-> JS v0.4-dev1 cold/warm session acceptance.
- Warm reconnect with a fresh JS registry and retained content-address cache requires zero definition network requests.
- Revalidated against Alchemy Objects v0.8 and Queue Fabric v0.9-dev4.
- Expanded Alchemy STANDARD adoption coverage to 17 representative Wire UI object types.
- `WIRE-UI/0.1` remains unchanged.

## v0.7

- Activated the existing subscription observation concept with immutable `WireUIObservationDefinition`.
- Added JS-compatible `OBSERVATION_PLAN` emission from active observation subscriptions.
- Added strict `INTERACTION_OBSERVATION` intake validation for subscription state/revision, point, purpose, evidence strength and allowed fields.
- Added canonical factual `WireUIObservationRecord` and deduplicated `drainObservations()` hand-off.
- Added server-stamped site-release/view provenance without turning browser assertions into authority.
- Added ooRexx-only positive-list security acceptance and real ooRexx ↔ JS v0.4-dev1 observation cross-wire acceptance.
- Rebased validation on Builder v0.2, Alchemy Objects v0.7 and Queue Fabric v0.9-dev4 from `oorexxapis(20260824-170926)`.
- Expanded Alchemy STANDARD adoption coverage to 15 representative Wire UI object types.
- `WIRE-UI/0.1` remains unchanged; these observation message kinds already exist in the current JS protocol.


## v0.6

- Added server-authoritative runtime consumption of Builder-compiled element experiments.
- Added `WireUIExperimentAssignment` as an AlchemyObject with PRIVATE assignment-subject state and wire-safe provenance.
- Added exact experiment/variant validation and exact projection-to-definition resolution; no `latest` fallback.
- ACTIVE/PREFETCH/ON_DEMAND release subscriptions now materialise the assigned exact variant definition.
- Journey plans and snapshots carry experiment assignment provenance without leaking the assignment subject.
- Experiment assignments remain profile-aware and do not force a human projection into an AI-agent profile.
- Revalidated the full package against Alchemy Objects v0.7 and Queue Fabric v0.9-dev4.
- Expanded Alchemy STANDARD adoption coverage to 13 representative Wire UI object types.
- `WIRE-UI/0.1` remains unchanged.


## v0.5

- Added `WireUISiteReleaseBinding` for immutable runtime binding to an exact sealed site release and compiled package.
- Added `WireUICompiledCatalogue`, consuming the public `wire_ui_builder_v0.1` compiled-package contract without a runtime dependency on Builder classes.
- Preserves Builder `definitionKey` and definition `contentAddress` exactly; no implicit latest-version resolution.
- Compiled journey states are materialised as release-managed ACTIVE/PREFETCH subscriptions and capability-specific ON_DEMAND subscriptions.
- Added generic profile switching across compiled HUMAN_VISUAL / AI_AGENT_OPTIMISED plans from the same release.
- Added exact site-release provenance to journey plans, definition offers, snapshots/resync and profile offers.
- Added optional action-side release provenance validation (`SITE_RELEASE_MISMATCH`).
- Expanded Alchemy STANDARD adoption validation from 10 to 12 representative Wire UI object types.
- Added Builder -> Server compiled-release acceptance using the OurLadyAir design fixture.
- Integration target advanced to Alchemy Wire UI JS v0.4-dev1; `WIRE-UI/0.1` remains unchanged.

## v0.4

Integration-lock cut: exact definition versions, canonical journey/on-demand/profile wire semantics, Builder definition-key meeting point and real ooRexx↔JS cross-wire acceptance.
