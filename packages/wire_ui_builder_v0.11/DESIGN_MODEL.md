# Wire UI Builder v0.11 — Design Model

## Authoring world versus published world

```text
WireUIBuilderProject                     WireUISiteRelease
  mutable project revision                 immutable version
  draft artifacts                          exact refs only
  cheap autosave                           SHA-512 graph seal
  typed operation ledger                   deployable
  incomplete states allowed                compiler-valid closure
          |                                      ^
          +-------------- publish --------------+
```

`WireUIDesignWorkspace` remains the registry of immutable artifacts. v0.11 retains `WireUIBuilderProject` above it so normal interactive edits do not create public versions.

## Stable semantic identity

Stable identity and immutable version identity remain separate:

```text
SEARCH_FORM                  semantic identity
PROJECTION:SEARCH_CONTROL@3  exact immutable projection
```

A published release contains no `latest` reference.

## Draft operation vocabulary

Current project verbs:

```text
DESIGN.COMPONENT.DRAFT
DESIGN.ELEMENT.DRAFT
DESIGN.MATERIAL.DRAFT
DESIGN.CONDITION.DRAFT
DESIGN.PRESENTATION_POLICY.DRAFT
DESIGN.PROJECTION.DRAFT
DESIGN.JOURNEY.DRAFT
DESIGN.EXPERIMENT.DRAFT
DESIGN.COMPOSITION.DRAFT
DESIGN.COMPOSITION.MOVE
DESIGN.COMPOSITION.RESIZE
DESIGN.COMPOSITION.RELOCATE
DESIGN.COMPOSITION.ALIGN
```

Each operation carries an expected project revision. A stale operation returns `DESIGN_REVISION_CONFLICT`; operation IDs are idempotent and conflicting reuse is rejected.

`DESIGN.PUBLISH` is handled by the owning Builder application because publication is an application-level decision, not another draft mutation.

## Studio and target separation

`WireUIBuilderApplication` binds the sealed first-party Studio package to its own view but receives a separate `WireUIBuilderProject` as the target. Studio actions mutate only that target.

This is the core consumer-independence invariant.

## Source catalogue

`WireUISourceCatalogue` is evidence for authoring and self-hosting, not source-control authority. It recursively discovers `.cls` files, retaining logical paths plus class/method/attribute/constant/require/package-option information. Large source files use a native string hash fingerprint for responsive browsing; strong source history can be supplied independently by Semantic Source Control. The logical path is also the collection identity, preventing duplicate basenames from colliding. `SOURCE.OPEN` projects structured catalogue evidence into a readable authoritative Studio source-detail state.

The Builder release graph itself is still strongly sealed at publication.

## Persistence

Project JSON schema:

```text
wire-ui-builder-project-v0.7
```

A saved project contains:

- project identity/title/revision/metadata;
- all current draft snapshots;
- the complete typed operation ledger;
- a deterministic project content address.

Load reconstructs operation objects and draft snapshots and rejects content mismatches or an incomplete operation ledger.

## A/B

Experiments are still attached to semantic elements rather than pages. Multiple exact projection artifacts can be pinned into one release and `WireUIExperiment` chooses one exact projection variant. v0.3 adds a project-level publication regression proving this works from drafts through compile and preview.

## Evidence boundary

Interactive identities/fingerprints are deliberately cheap. Strong cryptographic evidence is requested explicitly (`auditDigest()`) or created at immutable publish boundaries. Crypto v0.3 may satisfy whole-operation evidence through Runtime Reference dispatch and retains the native ooRexx fallback/API. Interactive source browsing/autosave still avoids forcing strong digest work on every gesture; immutable publication boundaries retain strong release evidence.

## Semantic composition

A composition is a versioned authoring artifact attached to an exact journey, interaction profile and journey state. Placements normally name semantic elements, not projections, so experiment variants can replace projections while retaining the same layout. A placement may explicitly name a projection only when the variant requires a different arrangement.

```text
Journey MAIN / state HOME / HUMAN_VISUAL
  THING      region=main order=10 span=8 viewport=DEFAULT
  ACTIONS    region=side order=20 span=4 viewport=DEFAULT
```

The browser may render those hints as CSS Grid, but CSS/DOM is not persisted as authoring truth. Browser gestures become typed `DESIGN.COMPOSITION.MOVE`, `RESIZE`, `RELOCATE` or `ALIGN` operations and are applied through the project revision ledger. Journey-state thumbnails are derived from composition drafts; they are evidence/presentation, not separate screen artifacts.

Published definitions receive compatible `metadata.compositionHints`; package-level `compositions` support preview/evidence. Existing `WIRE-UI/0.1` runtimes may ignore these additive fields.

## Visual preview and experiments

Draft preview uses target draft composition state. Published preview calls `WireUICompiler.previewManifest()` against the exact sealed release and optional explicit experiment assignment. Thus visual preview reports the same exact projection/version that runtime experiment resolution would select.

v0.11 preview scenarios may also provide explicit condition outcomes (`TRUE`, `FALSE`, `UNKNOWN`) for authoring simulation. These values are test inputs only. They let a designer inspect which conditional placements survive admission/arbitration and which conditional journey edges are admissible without claiming that browser/preview state is production authority.

## Conditional participation and presentation arbitration

A journey state's `ACTIVE` / `PREFETCH` / `ON_DEMAND` lists describe semantic candidates. A composition may make a candidate conditional by attaching exact condition identities to its placement. At compile time, conditional-only candidates are separated from ordinary delivery:

```text
authoritative FACT / DECISION
          |
          v
       CONDITION
          |
          v
conditional placement ---- PRESENTATION_POLICY
          |                         |
          +------------+------------+
                       v
             authoritative admission
                 |             |
              selected       absent
                 |             |
          definition/instance  nothing
```

The compiled journey state contains `CONDITIONAL_PARTICIPANTS`. Each participant pins exact condition refs, exact definition keys, its source tier, composition ref, presentation policy ref, presentation class and placement evidence. Conditional-only definitions are not listed in ordinary tier arrays. `unknownConditionalRuntimePolicy=OMIT` means a runtime that cannot evaluate this contract fails closed instead of showing an ineligible offer.

Condition truth, presentation eligibility and presentation selection are distinct. A fact can be true while a valid presentation loses arbitration because a higher-priority service/safety placement occupies a constrained region.

## Journey flows and conditional transitions

Flows are named structures inside a journey, not detached applications. Each flow has an initial state; every state belongs to a flow when flows are used. Semantic transitions may cross flow boundaries. This allows an ordinary journey state to expose a conditional doorway into a service-recovery flow while preserving one authoritative application journey.

A transition may carry exact semantic condition identities:

```text
fromState
toState
trigger
purpose
whenMode                 ALL | ANY
whenConditionIds[]
suppressConditionIds[]
```

Compilation pins those IDs to exact CONDITION refs. Conditional edges advertise `admissionMode=AUTHORITATIVE` and `unknownConditionPolicy=DENY`; an unknown condition never becomes an optimistic route. This is deliberately parallel to conditional placement fail-closed behaviour, while preserving the important distinction that presentation omission and navigation denial are different decisions.

Authoring preview can evaluate those edges from explicit preview condition outcomes and returns both `admissibleTransitions` and `transitionDecisions` evidence. Production runtimes must instead evaluate against authoritative business/service facts.

## Resource boundary

`WireUIResourceRef` is an exact reference to a resource published outside the Builder:

```text
resourceId
version
contentAddress
resourceClass  TEXT | GRAPHIC | AUDIO | VIDEO | STRUCTURED | COMPOUND | OTHER
locale         optional
```

A projection binds resource refs under semantic roles such as `PRIMARY_CONTENT`. The Builder does not store resource bytes, file paths, URLs or arbitrary presentation copy. There is deliberately no `Label: [type text here]` feature and no `Insert image` feature. The separate Resource Editor authors/version resources and feeds their immutable identities to Builder.

User-entry controls are different: they edit typed business facts. A natural-language customer-description fact can legitimately contain user text; that does not make the Builder a copy-authoring tool.

