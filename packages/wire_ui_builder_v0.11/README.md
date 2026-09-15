# Alchemy Wire UI Builder v0.11

Standalone semantic authoring application and compiler for Wire UI.

The Builder is a product in its own right. Application-specific systems are downstream consumers and compatibility fixtures; none of their business vocabulary is part of the Builder model, Studio release, web shell, or mandatory test suite.


## What v0.11 adds

v0.11 makes conditionality part of both presentation **and flow**. It retains v0.10's real SOURCE/COMPONENTS/MATERIALS/FLOW/PUBLISH perspectives and Server v0.16 workspace model, then adds conditional semantic journey edges and authoring-time condition simulation over the same revisioned `WireUIBuilderProject`.

### Conditional flow edges are first-class facts

Journey transitions may reference exact `whenConditionIds` and `suppressConditionIds` with `ALL` / `ANY` semantics. The compiler resolves them to exact sealed CONDITION refs and marks conditional transitions `AUTHORITATIVE_ADMISSION_REQUIRED`. A runtime that does not know the condition result must deny the edge; the browser never evaluates or invents the predicate.

`WireUIPreviewScenario` may carry explicit TRUE/FALSE/UNKNOWN condition outcomes strictly for authoring simulation. `previewManifest()` uses those preview facts to evaluate conditional placements, presentation arbitration and admissible transitions together, returning decision evidence. This does not create a second production authority: live applications still obtain condition truth from their authoritative business/service facts.

FLOW now exposes branch counts, conditional branch summaries and conditional placement summaries. Selecting a journey exposes/edit its transition facts (`fromState`, `toState`, semantic trigger, purpose, admission conditions and suppression conditions) through ordinary validated Builder actions. This makes cases such as `LAST_FLIGHT --[BAG_LOST] / BAG.RECOVERY.OPEN--> BAG_STATUS` explicit journey facts rather than hidden browser navigation code.

### SOURCE is an authoritative large-collection workspace

SOURCE no longer sends the whole source catalogue to the browser. The server owns a `BUILDER_SOURCE` workspace with independent query, membership-scope, ordering and semantic-selection revisions. The browser receives only a bounded `WireUICollectionWindow` of source-row instances.

- filtering changes membership scope and invalidates an old source selection;
- sorting changes ordering but preserves semantic selection identity;
- window offset/limit are authoritative and large catalogues need not exist in the DOM;
- selecting a row identifies a stable logical source path and projects the structured source facts into SOURCE DETAIL;
- source content addresses/symbol inventories remain authoritative detail evidence, not list-row decoration.

Server v0.16 coherent state groups are used for related Builder facts, so selecting a flow state, resizing a placement, opening SOURCE detail, or populating a typed editor does not expose intermediate half-updated view revisions. SOURCE window metadata/control changes are emitted before the final collection reconciliation, making a newly visible row actionable only at the current authoritative revision.

### COMPONENTS, MATERIALS, FLOW and PUBLISH are working perspectives

The same semantic artifact catalogue is reused with perspective-specific filtering instead of inventing independent panel state. COMPONENTS exposes component/element/projection drafts, MATERIALS exposes materials, FLOW exposes journeys/conditions/presentation policies/experiments, and PUBLISH sees the complete draft set for release review. Selecting an artifact populates its typed editor from the authoritative draft. Returning to DESIGN sees the same facts.

This is intentionally a **fact editor for a flow**, not an HTML/DOM/Swing editor. Browser or Swing renderers remain projections of the compiled facts.

### Conditional participation is authoritative, not CSS hiding

- `CONDITION` artifacts describe declarative predicates over authoritative `FACT` or `DECISION` sources. They contain no browser script and no arbitrary expression language.
- Composition placements may name exact `whenConditionIds` and `suppressConditionIds`, a `whenMode`, and a `presentationClass`.
- `PRESENTATION_POLICY` artifacts define precedence and region capacities for simultaneously-valid placements.
- The compiler resolves condition IDs to exact sealed condition refs. Conditional-only elements are removed from ordinary `ACTIVE` / `PREFETCH` / `ON_DEMAND` participation and emitted as `CONDITIONAL_PARTICIPANTS`.
- The compiled contract says `AUTHORITATIVE_ADMISSION_REQUIRED` and `unknownConditionalRuntimePolicy=OMIT`. A runtime that does not understand conditional admission therefore fails closed: it does not subscribe or deliver the conditional-only definition.
- The same semantic element may still participate normally in another flow/state.

### Resources are external, exact and immutable

The Builder does **not** author display copy or resource bytes. It has no free-text label/copy editor and no "insert image" surface. A separate Resource Editor/resource authority creates and versions resources. Builder projections only bind exact `WireUIResourceRef`s (`resourceId`, exact `version`, `contentAddress`, `resourceClass`, optional `locale`) under semantic roles. Literal display-content/file/URL escape hatches are rejected during draft validation.

See `RESOURCE_EDITOR_MEETING_POINT.md` for the deliberately narrow contract with the separate Resource Editor workstream.

### Studio/runtime

The Studio has **23 definitions / six contextual compositions**. The first-party live stack is ooRexx 5.3.0 r13196 → Wire UI Server v0.16 → the same Queue Fabric manager → Web Gateway v0.2 → Alchemy Wire UI JS v0.4-dev4. Crypto v0.3 is the current evidence/sealing dependency and may use Runtime Reference whole-operation dispatch while preserving its native ooRexx fallback/API.

The compiled runtime contract remains `WIRE-UI/0.1`; authoring schema remains `WIRE-UI-DESIGN/0.7` and project persistence remains `wire-ui-builder-project-v0.7`. The first-party Studio release is `WIRE_UI_BUILDER_STUDIO@0.11`.

## What v0.4.1 adds

v0.4.1 is a Studio usability cut on the existing `WIRE-UI-DESIGN/0.4` authoring schema. It adds a semantic `STUDIO.NAVIGATE` tool navigator and six contextual Studio states/compositions (`DESIGN`, `SOURCE`, `COMPONENTS`, `MATERIALS`, `FLOW`, `PUBLISH`). The browser composition controller presentation-hides instances that are outside the active composition while never hiding the Studio shell itself. No runtime wire-contract change is introduced.

## What v0.4 adds

v0.4 introduced semantic visual composition while preserving the runtime wire contract `WIRE-UI/0.1`. The authoring schema advanced to `WIRE-UI-DESIGN/0.4` and project persistence to `wire-ui-builder-project-v0.4`; the subsequent v0.4.1 usability cut advanced the first-party Studio to `WIRE_UI_BUILDER_STUDIO@0.4.1`.

- `WireUICompositionDesign` is a versioned, state/profile-aware layout artifact using typed renderer hints (`GRID12`/`FLOW`, region, order, span, row span, alignment and viewport class), never DOM selectors or arbitrary CSS.
- Draft operations `DESIGN.COMPOSITION.DRAFT` and `DESIGN.COMPOSITION.MOVE` make visual placement and drag ordering part of the same revisioned operation ledger used by AI/programmatic authors.
- Builder Studio dogfoods two first-party compositions (`DESIGN` and `SOURCE`) and adds composition canvas/editor plus preview control/summary surfaces.
- The browser-local `composition-controller.js` interprets compiled composition metadata and converts drag gestures into typed semantic actions; it does not mutate the target model locally.
- Composition remains element-centric by default, so A/B experiments can switch exact projections without silently forking layout. Optional projection-specific placement remains available when a variant genuinely needs different composition.
- Published preview resolves the real compiled manifest, exact A/B assignment and exact active definitions rather than echoing draft/browser state.
- A backwards-compatible Wire UI Server v0.16 action-binding extension permits one instance to expose multiple independently validated semantic actions, required for canvas select + move. The protocol remains `WIRE-UI/0.1`.

## What v0.3.1 adds

v0.3.1 hardens the Builder's self-source evidence surface for Semantic Source Control v0.2.2 while keeping authoring schema `WIRE-UI-DESIGN/0.3`, project persistence `wire-ui-builder-project-v0.3`, and compiled runtime contract `WIRE-UI/0.1` unchanged.

- `::constant` and `::options` are now visible in the built-in source catalogue and Builder Studio source detail.
- source catalogue wire output includes attribute/constant/package-option counts.
- optional SSC dogfood validates first-class attribute and constant surfaces.
- Builder Studio advances to `WIRE_UI_BUILDER_STUDIO@0.3.1` because its source-detail vocabulary expanded.

## What v0.3 added

v0.2 established immutable semantic artifacts, exact-version compilation, typed design operations, A/B experiments, multi-user preview and render evidence. v0.3 adds the missing authoring-application layer:

- `WireUIBuilderProject` — mutable, revisioned target project. Ordinary visual/AI edits create drafts, not public artifact versions.
- `WireUIBuilderDraft` — one immutable snapshot of current draft content at a project revision.
- `WireUIBuilderProjectActionAdapter` — consumer-neutral `DESIGN.*.DRAFT` action entry point.
- `WireUISourceCatalogue` — source-aware authoring evidence over a complete `.cls` tree with relocation-stable logical paths and fast live fingerprints.
- `WireUIBuilderStudioFixture` — the Builder's own first-party versioned component/element/projection/material/journey vocabulary.
- `WireUIBuilderApplication` — Wire UI application that serves Builder Studio while mutating a separate target project.
- `studio/wire_ui_builder_studio_v0.11.json` — precompiled, sealed Builder Studio interaction package.
- `web/` — consumer-neutral browser shell that renders the Studio package through the normal Wire UI JS/gateway path.

## Two projects, deliberately

The editor and the site being edited are not the same project:

```text
Builder Studio project
    compiled once as WIRE_UI_BUILDER_STUDIO@0.11
            |
            v
WireUIBuilderApplication
            |
            +---- renders the editor itself
            |
            +---- DESIGN.* actions ----> Target WireUIBuilderProject
                                          mutable drafts
                                               |
                                         explicit publish
                                               v
                                    immutable interaction package
```

A consumer application never becomes part of Builder Studio merely because the Builder is used to edit it.

## Draft versus published version

A project can receive many visual/AI operations:

```text
project revision 0 -> 1 -> 2 -> 3 -> ...
```

while its immutable workspace still contains zero public artifacts. `publish()` is the explicit materialisation boundary. It creates exact component/element/material/projection/journey/experiment versions, pins them into one site release and SHA-512 seals the release graph.

This avoids manufacturing a public UI version for every mouse move or AI proposal.

## Operation evidence

Draft operation identity uses a fast deterministic address suitable for interactive editing. `WireUIDesignOperation.auditDigest()` produces SHA-512 evidence on demand. Project autosave persists the complete typed operation ledger without forcing that expensive digest on every save.

Published release graphs remain SHA-512 sealed.

## Self-hosting / source-code dogfood

The Builder is tested over its own shipped ooRexx source rather than only canned application fixtures.

`WireUISourceCatalogue.addTree()` scans all `.cls` files under the Builder package boundary (core, integration application and first-party Studio fixture), discovers classes/methods/attributes/constants/requirements/package options and presents that source catalogue as real Builder Studio state.

The self-hosting acceptance then sends genuine Wire UI `UI_ACTION` messages through Wire UI Server v0.16 to create a separate target component, semantic element, material, projection and journey, and publishes the resulting target release.

Semantic Source Control v0.2.3 (or a compatible later analyzer) can optionally scan the same package as independent corroborating evidence. It is not a Builder runtime dependency.

## First-party Studio vocabulary

The Studio release currently provides generic authoring and visual-composition surfaces for:

- source browser/detail;
- component drafts;
- semantic element drafts;
- projection drafts;
- material token drafts;
- journey/state drafts;
- two-variant element-centric experiments;
- semantic composition canvas/editor and compiled preview controls;
- explicit publish.

The renderer primitives are generic (`FORM`, `TOKEN_FORM`, collection/list, `SEMANTIC_RECORD`, `PANEL`). No airline, banking or travel component is required.

## A/B and preview

A/B remains element-centric. A target project can publish two exact projection artifacts for the same semantic element and bind them through a versioned experiment. `WireUICompiler.previewManifest()` resolves the exact projection for each test subject or explicit variant assignment.

Multi-user/profile preview, authenticated-audience filtering, renderer evidence, assessments and proposals remain available from v0.2.

## Runtime meeting point

Validated integration baseline:

- ooRexx 5.3.0 r13196;
- Alchemy Objects v0.8;
- ooRexx Crypto v0.3;
- Wire UI Server v0.16;
- ooRexx Queue Fabric v0.9-dev4;
- Queue Fabric Web Gateway v0.2;
- Alchemy Wire UI JS v0.4-dev4.

Optional external source-evidence validation:

- ooRexx Semantic Source Control v0.2.3 (optional; compatible later analyzers may be used).

The compiled interaction package remains on `WIRE-UI/0.1`; v0.11's draft/composition project and Studio classes are authoring-time concepts and are not required by a runtime merely serving an already compiled target package.

## Run the live Studio

The preferred development entry point is the package launcher, not a generic static web server. If the exact runtime packages are already extracted under one directory:

```sh
./run_builder_studio.sh --runtime-dir /path/to/runtime-packages --open
```

A roll-up plus the separately supplied Server/ooRexx packages can also be resolved automatically:

```sh
./run_builder_studio.sh \
  --rollup /path/to/oorexxapis.zip \
  --server-zip /path/to/wire_ui_server_v0.16.zip \
  --oorexx-deb /path/to/oorexx-5.3.0-13196.x86_64.deb \
  --open
```

Use `--port 0 --json` for automated tests or when an ephemeral local port is preferred. The launcher prints the single browser URL after the ooRexx backend and official Web Gateway are both ready.

The runtime topology is intentionally explicit:

```text
Firefox / browser
    |
    | HTTP assets + WebSocket Wire UI
    v
Queue Fabric Web Gateway v0.2
    | private loopback bridge
    v
SAME ObjectQueueManager instance
    |
Wire UI Server v0.16
    |
WireUIBuilderApplication
    |
Target WireUIBuilderProject
```

`python -m http.server` may serve files, but it cannot instantiate this runtime and therefore is **not** a valid way to run the Builder. A page that loads but then reports `QUEUE_BACKEND_FAILED` is a runtime/bridge startup problem, not evidence that the browser shell should be reimplemented in Python.

## Build the first-party Studio package

```sh
ALCHEMY_OBJECTS_SRC=/path/alchemy_objects_v0.8/src \
OOREXX_CRYPTO_SRC=/path/oorexx_crypto_v0.3/src \
OOREXX_HOME=/usr/local \
./tools/build_studio_package.sh
```

The resulting `studio/wire_ui_builder_studio_v0.11.json` is source-relocation independent: the embedded source catalogue uses logical `builder/...` paths rather than build-machine absolute paths.

Source collection item identity is the logical path, not the basename or absolute host path. `SOURCE.OPEN` is a real Wire UI action: it projects the selected file into the authoritative source-detail instance, where classes, methods, attributes, constants, requirements and package options are readable through the normal browser renderer.

## Tests

`run_tests.sh` requires Alchemy Objects and Crypto paths. Server and JS integration are enabled when their paths are supplied. The real live-runtime test is also enabled when `QUEUE_FABRIC_SRC`, `WUIB_GATEWAY_ROOT`, `WUIB_JS_ROOT`, and `WUIB_REXX` are supplied. Semantic Source Control validation is enabled only when `SSC_ROOT` is supplied.

The mandatory Builder tests require no consumer application.
