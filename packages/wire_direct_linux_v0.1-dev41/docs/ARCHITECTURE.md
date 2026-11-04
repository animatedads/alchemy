# Architecture — dev3

Application behaviour -> Wire model/controller -> wire.renderer ABI -> renderer.

ABI 2 adds the first renderer-driven data primitive: `bind_list` + `show_list_range`. A renderer sees a logical collection only through `count` and bounded `range`; it cannot require materialisation of the full collection. Stable row identity crosses the boundary separately from presentation strings.

GTK4 is an implementation detail of `src/wire_gtk4_renderer.c`. Application Rexx, the IMAP adapter, tests, and public headers contain no GTK object types or signal APIs.

## dev6 authority rule
A class/module is not allowed to become an application-shaped dumping ground. Wire separates five authorities: Builder/design geometry, Renderer/native mechanics, Source/domain protocol, Projection/binding, and Scheduler/time policy. A worker thread is not an architectural boundary by itself.

The selected-message path is therefore split into a generic `WireSelectionProjection`, mail-specific `WireImapMessageResolver`, and semantic `WireElementTarget`. The dev5 `WireMailReaderController` remains only as a composition compatibility facade and contains no source operation or UI lookup.

`tests/test_architecture_boundaries.py` is a negative dependency qualification. It deliberately fails on representative forbidden vocabulary crossing these boundaries.

## dev7 semantic subject and assessment seams

Wire now has a deliberately small semantic-subject carrier and two generic projections. `WireEventSubjectProjection` converts an existing semantic event context identity into `WireSubjectRef`; it does not record observations or outcomes. `WireAssessmentProjection` decorates a semantic target from an injected assessment resolver; it does not train a model, alter source records, or reorder collections.

These are integration seams, not replacement subsystems. Existing Client Interaction, Observation, Outcome, and ML components remain authoritative. In-process packaging does not collapse those authority boundaries.

Failure containment is intentional: source/content projection works without observation or ML; observation failure cannot prevent reading content; assessment failure cannot mutate source state; a refreshed assessment cannot implicitly reorder the active collection.

## dev8 — exact Interaction Event capture port

`WireInteractionCapturePort` is a deliberately thin adapter to the externally owned Interaction Event v0.3 capture authority. It accepts already-created authority-owned objects and delegates only to verified v0.3 operations: `captureEvent`, `addLink`, and `assessmentsFor`. Wire does not construct `InteractionEvent`, `InteractionLink`, or `InteractionAssessment` and does not invent outcome/observation shortcuts.

The exact qualified v0.3 API does **not** expose `markOutcome`, `captureObservation`, or `attachEvidence` on `InteractionCaptureLibrary`. Outcome semantics must therefore remain represented by the owning interaction/event/link/assessment contracts rather than by a Wire compatibility fiction.

## Observation v0.5 consumer boundary (dev9)

`WireObservationConsumerPort` is deliberately a consumer-only adapter over the
existing `ObservationQueueService` v0.5 authority.  It delegates `checkpoint`,
`replay`, `commitCheckpoint`, and `discover`; it does not construct observation
evidence or replay/checkpoint objects, register producers/streams, publish
records, deliver Queue Fabric payloads, or train/classify anything.

This preserves the v0.5 separation between semantic observation state,
transport delivery state, and per-consumer checkpoints.  A Wire/ML consumer can
therefore replay retained evidence under its own checkpoint without turning
Wire Direct into an observation store or producer authority.

## Historical assessment projection (dev10)

Derived state remains downstream. `WireAssessmentStore` keys an externally produced assessment by stable subject identity plus assessment kind and the exact ML historical provenance tuple `modelId/modelPoint/branch`. `WireAssessmentView` selects one provenance tuple for presentation. Absence remains absence; no UNKNOWN assessment is synthesized. Changing the selected model history never mutates the source collection and has no ordering authority.

### dev11 visible-row update boundary

A derived assessment may decorate an already-visible stable identity through `set_list_row_property`. This operation has no collection mutation, sorting, source-fetch, observation, or training authority. A renderer may reject an identity that is not currently visible. Assessment arrival never implies collection reorder.

## dev12 MailReader behaviour composition

`WireMailReaderBehaviour` is a composition root, not a new interaction or analytics subsystem. Selection first resolves the stable semantic subject, then delegates the semantic selection boundary to an application-supplied interaction boundary, performs the existing content selection projection, and finally permits an already-produced sparse assessment to decorate that visible subject. `assessmentChanged(subjectRef)` is independently callable for asynchronous/background assessment arrival.

The interaction boundary is intentionally application supplied: Wire does not construct Interaction Event, Observation, Outcome, or ML objects and does not own investigation timing. Assessment arrival cannot fetch a mailbox range, train a model, or reorder the collection.

## Executable application model (dev13)
The Builder edits the same `WireApplicationModel` consumed at runtime. `WireBinding` records semantic source/trigger and behaviour target/method; `WireApplicationController` performs generic dispatch. Renderers translate native activity into `WireApplicationEvent` before this boundary. Source protocols, renderer mechanics, ML/Observation authority, geometry, and scheduling do not enter the binding model. Execution/current-task-async policy is deferred until its scheduler contract is implemented rather than encoded speculatively.

## Builder symbolic binding boundary (dev14)

The Builder does not persist live Rexx behaviour objects. `WireBuilderSession`
creates `WireBuilderBindingSpec` records containing stable source, trigger,
behaviour name and method. At runtime `WireBehaviourRegistry` resolves the
symbolic behaviour once and `WireBindingCompiler` produces the executable
`WireBinding` used by `WireApplicationController`.

This makes the design-time gesture literally `element -> event -> behaviour`
without leaking renderer callbacks into the application model. It also avoids
serialising object identity and keeps runtime composition independently testable.

### dev15 foreign-language choke point

Wire's application dispatcher is always ooRexx.  A non-ooRexx code block is
represented by a Rexx `WireLanguageBlock` behaviour.  Entry projects a Rexx
variable collection through Alchemy; return crosses the foreign result back to
Rexx before Wire resumes.  There is no foreign-language traversal of Wire's
application graph and no engine-specific application-model state.

### dev16 completion boundary

Autocomplete is headless and follows the same language-block choke point as execution. The caret selects a language completion provider; the application graph does not change language. Providers receive the same live execution-visible variables, but completion is metadata-only and may expose only the capabilities that the real language projection grants. Raw ooRexx reflection is not a substitute for an Alchemy projection: an unprojected capability must not appear in completion. Completion must not execute user code, invoke arbitrary getters, materialise hidden objects, or widen authority. Language-native presentation is provider-owned, so Rexx messages, JavaScript members, and Prolog predicates need not share a syntactic completion model.

### dev17 filtered-window authority

Filtering owns an output window distinct from the backing-store pull window. `WireFilterWindow` alone decides when another upstream range is required. A predicate receives only a candidate `WireListRow`; it receives no `WireListSource` and cannot fetch. If a requested filtered window is not full, the controller pulls again until full or upstream exhaustion. It stops as soon as the output window is satisfied and resumes later at the first unconsumed backing ordinal. Backing ordinals and filtered ordinals are distinct; stable identity crosses the boundary unchanged.

### dev18 real JavaScript predicate qualification

The filtering stack is `source -> backing collection -> upstream pull window -> language predicate -> filter-owned output window -> renderer`. A language predicate is never given the backing source. Pull authority remains solely in `WireFilterWindow`.

`WireQuickJSPredicate` exists as a concrete QuickJS-NG qualification adapter and demonstrates actual JavaScript execution at the predicate seam. Production polyglot dispatch remains bounded by the ooRexx/Alchemy language-block crossing; the QuickJS adapter does not create a second application dispatch model.
