# Changelog

## v0.11

- Extends journey transitions with exact `whenConditionIds`, `suppressConditionIds` and `whenMode`, so exceptional/service-recovery flow edges can be conditional facts rather than browser routing code.
- Compiles transition condition IDs to exact sealed CONDITION refs and marks conditional edges `AUTHORITATIVE_ADMISSION_REQUIRED`; an unknown/non-capable runtime must fail closed with `unknownConditionalTransitionPolicy=DENY`.
- Adds explicit preview-only condition outcomes to `WireUIPreviewScenario`. Authoring preview can simulate TRUE/FALSE/UNKNOWN condition results without making preview/browser state authoritative for production facts.
- Extends `WireUICompiler.previewManifest()` so conditional placement admission, presentation-policy arbitration and admissible journey transitions are evaluated together and returned with decision evidence. Unknown conditional placements are omitted; unknown conditional transitions are denied.
- Makes FLOW show semantic branch summaries and conditional-placement summaries per state, including triggers, condition identities and suppression identities.
- Extends the JOURNEY editor with transition facts (`fromState`, `toState`, trigger, purpose, ALL/ANY admission conditions and suppression conditions) and persists edits through ordinary validated `UI_ACTION` -> `DESIGN.JOURNEY.DRAFT`.
- Adds FlyLo-style lost-bag acceptance proving `LAST_FLIGHT` can conditionally expose `BAG.RECOVERY.OPEN` into a named `BAG_RECOVERY` flow, while the same assistance element can participate unconditionally after entering that flow.
- Keeps the Resource Editor boundary unchanged: no display-copy authoring, insert-image control, file/URL escape hatch or resource-byte ownership is added to Builder.
- Retains the v0.10 Server v0.16 authoritative SOURCE workspace/coherent state-group projection and the 23-definition / six-composition Studio. Authoring schema remains `WIRE-UI-DESIGN/0.7`, project persistence remains `wire-ui-builder-project-v0.7`, runtime remains `WIRE-UI/0.1`.

## v0.10

- Turns SOURCE into a first-class authoritative workspace over Wire UI Server v0.16 query/scope/order/selection state rather than a whole-catalogue browser dump.
- Publishes only a bounded `WireUICollectionWindow` of source-row semantic instances; source filtering changes membership scope and invalidates stale selection, while sorting changes order and preserves semantic selection identity.
- Uses Server v0.16 `mutateStateGroup()` plus a Builder-derived state projector so multi-slot FLOW, composition, SOURCE-detail and editor updates become one coherent view revision rather than a cascade of transient revisions. SOURCE window controls are projected before the reconciled row window, so newly actionable rows appear only after the client has the current revision.
- Adds SOURCE window controls for filter, exact PATH ordering, direction, offset and bounded limit; source detail exposes current query/scope/selection revisions.
- Makes COMPONENTS, MATERIALS, FLOW and PUBLISH genuinely useful perspectives over the same target project by reusing the artifact catalogue with perspective-specific kind filters.
- Selecting a component, element, projection, material, journey, condition, presentation policy or experiment populates the matching typed editor from the authoritative draft rather than creating panel-local editor truth.
- Keeps resource authoring entirely outside Builder. Projection editors can bind exact external resource references; no arbitrary display-copy, image upload, file path or resource-byte authoring surface is introduced.
- Advances the first-party Studio to 23 definitions / six contextual compositions with `SOURCE_WINDOW` control and semantic source-row definitions.
- Moves the supported live baseline to Wire UI Server v0.16 and ooRexx Crypto v0.3; authoring schema remains `WIRE-UI-DESIGN/0.7`, project persistence remains `wire-ui-builder-project-v0.7`, and compiled runtime remains `WIRE-UI/0.1`.


## v0.9.1

- Fixes the SOURCE panel topology exposed by the live Firefox Studio: source catalogue and source detail are distinct 4/8 Studio chrome regions instead of two roots stacked inside one `source` wrapper.
- Makes the SOURCE collection carry only stable source paths. Structured symbol/content-address facts remain in the source catalogue and are projected only after `SOURCE.OPEN`, avoiding raw source-record dumps in the navigator.
- Extends the same chrome separation to COMPONENTS, MATERIALS, FLOW and PUBLISH so sibling authoring perspectives keep their authored horizontal relationship instead of collapsing into a shared wrapper.
- Adds explicit per-state named Studio grid areas while preserving the rule that target application regions remain semantic composition facts rather than Builder CSS.
- Retains the v0.9 conditional-participant, flow, presentation-policy and external-resource contracts unchanged.

## v0.9

- Adds first-class `CONDITION` artifacts over authoritative `FACT` / `DECISION` sources; conditions are declarative and contain no browser script.
- Adds first-class `PRESENTATION_POLICY` artifacts with precedence and per-region capacity for arbitration among simultaneously-valid placements.
- Extends composition placements with `whenConditionIds`, `suppressConditionIds`, `whenMode` and `presentationClass`; compiled placements resolve these to exact sealed condition refs.
- Adds fail-closed compiler semantics: conditional-only elements are removed from ordinary ACTIVE/PREFETCH/ON_DEMAND participation and emitted as `CONDITIONAL_PARTICIPANTS` with `AUTHORITATIVE_ADMISSION_REQUIRED` / unknown-runtime `OMIT`.
- Adds Server-backed regression proving Wire UI Server v0.12, which does not yet evaluate the new conditional contract, registers the sealed definition for provenance but never subscribes/delivers it.
- Adds named flows inside journeys, flow initial states and cross-flow semantic transitions while keeping state identity journey-scoped.
- Adds exact external `WireUIResourceRef` bindings (`resourceId`, version, content address, class, locale) to projections. Resource bytes remain outside the Builder.
- Enforces the product boundary that the Builder cannot author arbitrary display copy and has no image-upload/insert-image concept. Fixed presentation content is referenced only through external resources; the separate Resource Editor owns resource authoring.
- Adds `RESOURCE_EDITOR_MEETING_POINT.md` as the handoff contract for the separate Resource Editor product.
- Advances the Studio to 21 definitions while retaining six contextual compositions; FLOW now includes Condition and Presentation Policy editing perspectives.
- Retains the v0.8.4 Firefox-driven deterministic Studio topology (named areas / explicit rows), v0.8.1 root parking, v0.8.3 full-width shell, one-command live launcher and real Queue Fabric path.
- Keeps authoring schema `WIRE-UI-DESIGN/0.7`, project persistence `wire-ui-builder-project-v0.7`, and runtime `WIRE-UI/0.1`.

## v0.8.1

- Fixes the live-browser Studio region-stack lifecycle exposed by Firefox and Chrome: inactive Wire UI definition roots are now parked rather than deleted during journey-state changes.
- Makes region arrangement idempotent so the composition controller no longer re-appends already-parented live roots and retriggers its own `MutationObserver`.
- Forces the live Studio shell and semantic region stacks to stretch across one full-width workspace grid, preventing the canvas/filmstrip from collapsing to content width and eliminating the resulting placement-control overlap.
- Adds a state-switch regression that proves DESIGN → MATERIALS → DESIGN preserves the same live definition roots and stable region wrappers.

## v0.8

- Adds `run_builder_studio.sh`, the supported one-command live Studio development access point.
- Adds `tools/builder_live_backend.rex`, which owns the real ooRexx `ObjectQueueManager`, Wire UI Server v0.12, Builder application and access-point bridge in one process.
- Adds `tools/builder-live-host.mjs`, which launches the official Queue Fabric Web Gateway v0.2 and serves only Builder/JS assets plus bootstrap/health endpoints.
- Explicitly prevents the common static-server mistake: Python is not part of the Builder application runtime.
- Adds `WireUIBuilderLiveWorkspaceFixture`, a consumer-neutral 24-draft, six-state target used by the first live session and launcher acceptance.
- Adds a real end-to-end live test through ooRexx → Server → Queue Fabric → Web Gateway → Alchemy Wire UI JS, including `FLOW.SELECT` and a typed composition resize that advances the target revision.
- Fixes DESIGN-state definition authorisation by prefetching `BUILDER_SOURCE_FILES`, which the authoritative initial snapshot already instantiates. This removes the cold-session `DEFINITION_NOT_AUTHORISED_BY_MANIFEST WUIB_SOURCE_FILES@1` failure exposed by the live launcher.
- Advances the sealed Studio release to `WIRE_UI_BUILDER_STUDIO@0.8` while preserving authoring schema `WIRE-UI-DESIGN/0.7`, project persistence `wire-ui-builder-project-v0.7`, and runtime `WIRE-UI/0.1`.


## v0.7

- Advances the Builder product to `0.7` while deliberately retaining authoring schema `WIRE-UI-DESIGN/0.7`, project persistence `wire-ui-builder-project-v0.7`, and runtime `WIRE-UI/0.1`; this cut is an ergonomics/runtime-presentation release, not a new design-data schema.
- Makes canvas card clicks explicitly emit authoritative `COMPOSITION.SELECT` while maintaining local visual selection and linked artifact highlighting.
- Makes screen thumbnails first-class activation targets and keeps the filmstrip editing marker synchronised with the state-scoped canvas.
- Replaces region-cycling buttons with semantic region drop targets; dragging a placement grip onto a region emits `DESIGN.COMPOSITION.RELOCATE`.
- Replaces `−/+` resize buttons with a discrete 12-column drag handle plus keyboard resizing, still emitting only typed `DESIGN.COMPOSITION.RESIZE`.
- Adds a compact contextual placement inspector with region chips, span slider, alignment controls, and collapsed advanced semantic fields.
- Keeps drag-to-reorder on a dedicated grip and retains typed `DESIGN.COMPOSITION.MOVE`.
- Advances the sealed first-party Studio release to `WIRE_UI_BUILDER_STUDIO@0.7`; the Studio remains consumer-neutral at 19 definitions and six contextual compositions.

## v0.6

- Advances authoring schema to `WIRE-UI-DESIGN/0.7` and project persistence to `wire-ui-builder-project-v0.7`; compiled runtime stays `WIRE-UI/0.1`.
- Adds typed `DESIGN.COMPOSITION.ALIGN` with START/CENTER/END/STRETCH validation and draft-only revision semantics.
- Renders composition items as true 12-column span-aware cards with ruler and semantic region guides.
- Adds journey-state thumbnail signatures derived from target composition drafts.
- Scopes the active canvas to the initial/selected journey state instead of aggregating placements across screens.
- Keeps library, shared selection inspector, screen-flow strip and direct move/resize/relocate operations from v0.5.
- Keeps the first-party Studio at 19 definitions / six contextual compositions and advances it to `WIRE_UI_BUILDER_STUDIO@0.6`.
- Adds real Server v0.12 UI_ACTION acceptance for alignment and multi-screen state switching.
- Fixes aggregate test dependency-path handling for Server-backed Builder tests.

## v0.4.1

- Adds semantic `STUDIO.NAVIGATE` navigation to the first-party Builder Studio.
- Splits the monolithic DESIGN surface into six contextual authoring states/compositions: DESIGN, SOURCE, COMPONENTS, MATERIALS, FLOW and PUBLISH.
- Presentation-hides definitions outside the active composition without changing authoritative instance state.
- Fixes the composition container rule so `WUIB_SHELL` is never hidden for lacking a placement hint.
- Advances the first-party Studio release to `WIRE_UI_BUILDER_STUDIO@0.4.1`; authoring schema remains `WIRE-UI-DESIGN/0.4` and runtime remains `WIRE-UI/0.1`.

## v0.4

- Adds versioned `WireUICompositionDesign` and authoring schema `WIRE-UI-DESIGN/0.4`.
- Advances project persistence to `wire-ui-builder-project-v0.4` with v0.3 load compatibility.
- Adds typed `DESIGN.COMPOSITION.DRAFT` and `DESIGN.COMPOSITION.MOVE` operations.
- Adds Studio composition canvas/editor and compiled preview control/summary surfaces.
- Builder Studio now dogfoods two semantic compositions and publishes as `WIRE_UI_BUILDER_STUDIO@0.4`.
- Adds browser composition controller for viewport/layout interpretation and typed drag actions; DOM/CSS remain renderer outputs only.
- Adds A/B composition regression proving semantic element layout remains stable while exact projection variants change.
- Validates visual select/move/publish/preview through Wire UI Server v0.12 multi-action binding.
- Runtime wire contract remains `WIRE-UI/0.1`.


## v0.3.1

- Keeps Builder independent of Semantic Source Control; SSC remains optional corroborating evidence.
- Extends `WireUISourceCatalogue` / `WireUISourceFile` with first-class `::constant` and `::options` evidence alongside existing classes, methods, attributes, and requirements.
- Exposes aggregate attribute/constant/package-option counts in source catalogue wire state.
- Expands Builder Studio source-detail fields/bindings to show attributes, constants, requirements, and package options.
- Strengthens optional dogfood against Semantic Source Control v0.2.2 attribute/constant analysis.
- Advances Builder Studio release to `WIRE_UI_BUILDER_STUDIO@0.3.1`.
- Makes source collection IDs use relocation-stable logical paths, avoiding duplicate-basename ambiguity.
- Makes `SOURCE.OPEN` populate and switch the authoritative Builder Studio source-detail instance through normal Wire UI state projection.
- Renders source-detail classes/methods/attributes/constants/requirements/options as readable summaries while retaining structured catalogue evidence.
- Package version is `0.3.1`; authoring schema remains `WIRE-UI-DESIGN/0.3`; project persistence remains `wire-ui-builder-project-v0.3`; compiled runtime remains `WIRE-UI/0.1`.


## v0.3

- Makes the Builder a standalone consumer-neutral authoring application rather than only a design-object library.
- Adds `WireUIBuilderProject`: mutable draft revisions above the immutable `WireUIDesignWorkspace`.
- Adds `WireUIBuilderDraft`; many visual/AI edits no longer create public artifact versions.
- Adds explicit project publication which materialises exact immutable artifacts and SHA-512 seals one release graph.
- Adds project JSON save/load with complete typed operation-ledger persistence and content-integrity validation.
- Keeps draft operation identity/autosave fast while exposing SHA-512 `auditDigest()` only when strong operation evidence is requested.
- Adds `WireUISourceCatalogue.addTree()` and relocation-stable logical source paths.
- Uses native string hashing for responsive live source fingerprints; strong independent source-history validation is available through optional Semantic Source Control v0.2.
- Adds the first-party, versioned Builder Studio design and precompiled `wire_ui_builder_studio_v0.3.1.json`.
- Adds `WireUIBuilderApplication` / runtime factory: the Studio release and target project are separate objects.
- Adds consumer-neutral browser shell under `web/` using the normal Queue Fabric/Wire UI JS path.
- Adds self-hosting acceptance over all shipped Builder `.cls` files: core, integration application and first-party Studio fixtures.
- Adds real Server v0.10 `UI_ACTION` authoring acceptance against the Builder's own source catalogue.
- Adds independent target-project A/B draft → publish → preview acceptance.
- Adds explicit package identity/adoption regression for v0.3.
- Adds optional Semantic Source Control dogfood over the complete shipped Builder package.
- Updates current integration baseline to Alchemy Objects v0.8, Server v0.10 and JS v0.4-dev4.
- Keeps the compiled interaction package on the existing `WIRE-UI/0.1` runtime contract.

## v0.2

- Added revisioned immutable-workspace operations, lineage, multi-user preview matrices, render observation, assessments/proposals and the first Wire UI action adapter.

## v0.1

- Introduced the standalone semantic authoring/compiler layer, exact-version components/elements/projections/materials/journeys/releases, element-centric experiments and preview evidence.
