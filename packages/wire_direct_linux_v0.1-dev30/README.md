# Wire Direct Linux v0.1-dev22

First end-to-end identity-bearing VirtualList event checkpoint.

The public renderer ABI is now ABI 3. A `WireListRow` carries both a renderer-local numeric identity and an application `stable_id`. Selection is emitted as the semantic `SelectionChanged` trigger with `detail_key=identity` and the stable identity as its value. Renderers therefore do not send physical row positions back to application behaviour.

For mail the intended stable identity is `mailbox | UIDVALIDITY | UID`; the existing ooRexx IMAP dev8 adapter remains the authority for constructing those values. The headless renderer qualification uses a 200,000-row collection, asks for rows 8700..8799, selects visible row 37, and proves the resulting event identifies `INBOX|4242|8738`, not row 37.

The private GTK4 implementation now copies stable identity onto each transient `GtkListBoxRow` and translates GTK row activation to the same renderer-neutral `SelectionChanged(identity=...)` event. No GTK/GObject type appears in the public ABI.

GTK4 compile/runtime qualification remains conditional on GTK4 development files being installed. The neutral core is compiled with `-Wall -Wextra -Werror` and run on every build.

## dev5 selected-message path

`SelectionChanged` now has a renderer-neutral application controller path: stable `mailbox|UIDVALIDITY|UID` identity is validated against the selected mailbox collection, resolved to `WireImapMessageRef`, read through `WireImapMailboxCollection~fetchBody()`, and written to the semantic `Document.value` property. GTK4 privately maps `Document.value` to `GtkTextBuffer`; application Rexx contains no GTK or IMAP protocol command vocabulary.

## dev6 — authority separation
The dev5 end-to-end controller has been decomposed before further MailReader features are added. Selection projection is generic Wire plumbing; IMAP identity/body resolution is a source adapter; element lookup/property mutation is a semantic target. The old controller is now composition-only. Negative architecture tests reject representative renderer↔IMAP, projection↔renderer/protocol, target↔protocol, and Builder-geometry leakage.

### dev7
Adds renderer/source-neutral semantic subject transport (`WireSubjectRef`, `WireEventSubjectProjection`) and a generic derived-assessment decoration seam (`WireAssessmentProjection`). No Client Interaction, Observation, Outcome, or ML implementation is duplicated here; those remain injected/external authorities.

### dev8
Adds `WireInteractionCapturePort`, checked against the exact `interaction_event_v0.3-qualified` source contract. The port delegates already-authoritative objects through `captureEvent`, `addLink`, and `assessmentsFor`; it creates no parallel Interaction Event, Observation, Outcome, or Assessment model.

### dev9
Adds `WireObservationConsumerPort`, an exact consumer-only seam over ooRexx
Observation v0.5 `ObservationQueueService`.  Wire delegates discovery, replay,
checkpoint read and monotonic checkpoint commit.  Observation objects,
producer registration, retention, Queue delivery and ML interpretation remain
owned by their existing components.

## dev10 — historical assessment view

Adds a sparse `WireAssessmentStore` / `WireAssessmentView` boundary against the exact ooRexx ML dev11 `MLAssessment` shape (`kind`, `value`, `modelId`, `modelPoint`, `branch`). The application supplies already-produced assessments; Wire does not train, fit, reorder the source collection, or manufacture an absent assessment. Switching model point/branch changes only the selected projection and retains older assessments.

## v0.1-dev11 — visible assessment projection

ABI 4 adds one renderer-neutral operation: `set_list_row_property()` for an already-visible row identified by stable application identity. It does not fetch a range, change collection order, or create an assessment.

`WireVisibleAssessmentProjection` consumes the existing `WireAssessmentView` and projects only assessments that already exist. Missing assessment remains absence. `assessmentChanged()` updates one visible identity without re-reading the 200,000-row source. The GTK4 renderer implements `assessment`/`annotation` as presentation-only row annotation; application/ML semantics remain upstream.

### dev12
Adds the first MailReader semantic behaviour composition root. Selection carries stable subject identity through the application-supplied existing interaction/evidence boundary and content projection; already-produced assessments may decorate the visible row. Background assessment arrival has its own `assessmentChanged(subjectRef)` path and therefore does not require reselection, refetch, or collection rebuild. No interaction lifecycle, Observation, Outcome, or ML implementation is duplicated in Wire.

### dev13 — executable application model
Adds the first generic Builder/runtime model: `WireBinding`, `WireApplicationModel`, `WireApplicationEvent`, and `WireApplicationController`. A binding is semantic `source + trigger -> behaviour target + method`; dispatch uses the same model whether the binding was produced visually or by Rexx. The model has no GTK, IMAP, Observation, ML, MailReader, geometry, or scheduling vocabulary. Execution policy remains deliberately unimplemented rather than being guessed into the contract.

### dev14
Adds the first Builder editing path. `WireBuilderSession` implements the
object-first `select element -> select event -> bind behaviour` operation using
persistent symbolic `WireBuilderBindingSpec` records. Live Rexx behaviour
objects are resolved separately at runtime by `WireBehaviourRegistry` and
`WireBindingCompiler`; Builder state contains no renderer callbacks or live
object identity.

## v0.1-dev15 — bounded foreign-language blocks

Wire dispatch remains ooRexx.  `WireLanguageBlock` is an ordinary Rexx
behaviour object: it places the application event in an ooRexx variable
collection, calls one Alchemy-facing `executeBlock(language, source,
variables)` crossing, and returns the resulting ooRexx value normally.

This is the language boundary, not a second application dispatch system:

```
Wire -> ooRexx behaviour -> Rexx-to-langX variables -> language block
     <- normal Rexx return <- langX-to-Rexx result <-+
```

JavaScript Alchemy dev23 / QuickJS-NG 0.17.0 is pinned as the first concrete
foreign-language dependency, but neither JavaScript nor QuickJS appears in the
Wire language-block implementation.  The same boundary is intended for every
Alchemy language.  Engine scheduling, Promise/microtask handling, live-object
identity, exceptions and foreign-runtime policy remain Alchemy/runtime
responsibilities.

## v0.1-dev16 — bounded headless completion

Completion now has a renderer-free contract (`WireCompletionService`, `WireCompletionProvider`, `WireCompletionRequest`). The active code block selects the provider; Wire itself remains in ooRexx/application space. A provider sees the same live variables as execution but must derive suggestions from projection metadata only. The qualification suite proves the same live event identity can produce Rexx- and JavaScript-shaped suggestions, a restricted JavaScript projection cannot leak a withheld capability, completion invokes no object getter, and leaving/switching language blocks leaves no foreign completion state behind.

## v0.1-dev17 — pulling filtered windows

The collection path now has an explicit filtered-window controller: source → backing collection → bounded upstream pulls → predicate/language block → filter-owned output window → renderer. A selective filter may pull additional backing windows until its requested output window is full. The predicate receives rows only and has no source handle, so it cannot roam the backing collection itself. Continuation is the first unconsumed backing ordinal; stable application identity is preserved. Filling a 100-row filtered window is therefore controlled pull, not whole-collection materialisation.

## v0.1-dev18 — real JavaScript filtered-window qualification

The filtered-window predicate position is now qualified with the real locally-built QuickJS-NG 0.17.0 engine. `WireQuickJSPredicate` is a concrete qualification adapter: it compiles one JavaScript function, projects only the bounded `WireListRow` candidate handed to it, and returns the JavaScript truth value to `WireFilterWindow`. It has no source handle and therefore cannot pull or enumerate the backing collection.

The 200,000-row test uses a 1-in-8 JavaScript predicate. A request for 100 filtered rows causes exactly eight 100-row backing pulls / 800 JS calls and stops at backing ordinal 800. Subsequent requests resume from the continuation rather than restarting or materialising the collection.

This native adapter proves the predicate position with real JavaScript. It is not a replacement for JavaScript Alchemy: production Wire foreign-language blocks remain `ooRexx -> Alchemy -> language -> Alchemy -> ooRexx`. The current build container still lacks an ooRexx runtime, so the complete ooRexx/Alchemy crossing is not falsely reported as executed here.

## dev20 — real ooRexx → JavaScript Alchemy → QuickJS filter qualification

Dev20 closes the dev18 qualification gap.  `tests/test_oorexx_javascript_alchemy_filter.rex`
uses the exact ooRexx 5.3.0 r13196 runtime and JavaScript Alchemy dev23 QuickJS-NG provider.
A 200,000-row backing store is pulled in bounded 100-row windows; each candidate crosses
through ooRexx into `AlchemyJavaScriptQuickJSRuntime`, executes a real JavaScript predicate,
and returns the boolean to the filter-window controller.  The resulting 100 rows are then
passed through the native ABI4 TestRenderer using `wire_oorexx_renderer_package.cpp`.

The 1-in-8 predicate proves eight upstream pulls (800 rows fetched), but evaluation stops
at candidate 793 as soon as the 100th filtered result (identity 792) is found.  Thus the
last seven rows of the eighth already-bounded source pull are not evaluated, and the other
199,200 backing rows are never fetched.  JavaScript receives projected row scalars only;
it receives no backing-store or pull capability.

The native renderer helper is a qualification adapter, not a second application dispatch
architecture.  Production foreign-language dispatch remains ooRexx → language block →
ooRexx, with Alchemy owning the language crossing.

## dev21 — one application identity across ooRexx, JavaScript and Prolog

Dev21 makes the three-language MailReader composition an executable qualification rather than three independent demonstrations. `tests/test_three_language_composition.rex` owns one live mail object in ooRexx (`INBOX|4242|8738`). JavaScript Alchemy dev23/QuickJS-NG 0.17.0 receives only the deliberately bounded filter projection. The live ooRexx object is then mutated without changing identity and Prolog Alchemy dev13/SWI-Prolog 10.0.2 receives that same retained Rexx object through `rexxObject()`/`rexx_send/4`.

The qualification proves that the JavaScript result changes after the ooRexx mutation and that the subsequent Prolog `needs_attention/1` rule observes the mutated live object. Neither foreign language receives renderer authority; the JavaScript block receives no backing-store traversal capability, and the Prolog rule performs no GTK/Wire work. Runtime providers remain deployment dependencies rather than `.wire` application-model identities.

Run `scripts/qualify-three-language.sh` with the exact dependency roots described by its environment variables. The ordinary build remains dependency-light and does not silently turn missing language runtimes into a pass.

## dev22 — module-by-module stack authority graph

Adds `docs/MODULE_STACK.md` and `docs/module_stack.dot` as the maintained stack-level map of the qualified MailReader composition. The map separates application/model modules, source/windowing, language crossings, runtime providers and renderer modules. Edges are labelled by the authority crossing they carry; JavaScript remains a bounded candidate predicate and Prolog remains an explicit relational-query capability. Provider/runtime names remain below the Alchemy boundary and are not stored as application-model identity.

## dev23 — ooRexx Wire application-element proxy

Dev23 adds the behaviour-to-Wire half of the application contract. `WireUIProxy`
and `WireElementProxy` expose Builder-designed semantic element identity to ooRexx
without exposing GTK, DOM, Swing, or other renderer-native objects. Authoritative
state remains in `WireApplicationModel`; mutations are projected downstream through
`setElementProperty`, while `activate` is a separate semantic application action.

A proxy may be capability-scoped by element id. Possession is authority: an element
outside the supplied scope cannot be resolved through that proxy. `WireApplicationEvent`
can carry the scoped UI proxy so ordinary behaviour remains pleasantly small:

    event~ui~byId("detailsPanel")~visible = .true
    event~ui~byId("status")~text = "Ready"
    event~ui~byId("closeButton")~activate

`tests/test_ui_proxy.rex` is a real ooRexx r13196 behavioural qualification. It proves
that three state changes update authoritative model state and the semantic projection,
that an undisclosed element is not resolvable, and that `activate` travels through the
separate semantic action target rather than simulating renderer input.

## dev24 — native GTK application lifecycle checkpoint

The GTK renderer now owns a registered `GtkApplication`, creates Wire windows as
`GtkApplicationWindow` instances, and keeps the native event loop alive through the
renderer `run()` boundary.  `examples/wire_demo.c` is a deliberately thin host: it
constructs the renderer only through the public Wire ABI and projects a bounded 100-row
window from a synthetic 200,000-row collection.  Native row activation still returns
`SelectionChanged` plus the stable Wire identity; the demo contains no GTK calls.

This closes the launcher/lifecycle gap exposed by the first on-machine GTK run.  It does
not move application or collection authority into GTK.

## dev25 — MailReader semantic round trip

Adds `WireRendererEventPort`, the renderer-neutral ingress counterpart to the
dev23 `WireUIProxy`. Native renderers translate toolkit activity to semantic
`source + trigger + detail` before this boundary. The port constructs a
`WireApplicationEvent`, attaches the source-scoped UI capability, and dispatches
through the existing application controller.

The r13196 qualification drives a GTK-labelled semantic selection through the
whole application loop without importing GTK into Rexx behaviour:

```
GTK/native interaction (translated by renderer)
  -> messages.SelectionChanged(identity=INBOX|4242|8738)
  -> WireRendererEventPort
  -> WireApplicationController
  -> ordinary ooRexx behaviour
  -> event~ui WireElementProxy mutations
  -> authoritative WireApplicationModel
  -> renderer-neutral projection updates
```

During executable qualification this also exposed and repaired a real generic
controller defect: ooRexx `sendWith` requires its message arguments as a
single-dimensional Array. Dispatch now uses `.array~of(event)` rather than
passing the event object itself.

## v0.1-dev26 — MailReader over the real IMAP source adapter

The semantic selection round trip now composes the existing MailReader behaviour with
`WireImapMailboxCollection` and `WireImapMessageResolver`, rather than a mail-specific
fixture source.  Qualification uses a deterministic in-process IMAP session double so
it exercises the production Wire/IMAP adapter without requiring network credentials.

The acceptance case exposes 200,000 UIDs, requests only a 100-identity source window,
then selects `INBOX|4242|8738` outside that window.  Exactly one body fetch is issued,
for UID 8738, and its value returns through authoritative Wire element state and the
renderer-neutral projection.  List ordinal is therefore not selection authority.

## v0.1-dev27 — semantic GTK ingress + MailReader visual host

The GTK renderer now retains the Builder/Wire semantic `id` for each native
projection and emits that semantic id at event ingress.  A native list
activation therefore enters Wire as `messages.SelectionChanged`, rather than
leaking an implementation handle such as `7.SelectionChanged`.

`examples/wire_mailreader_demo.c` is the first three-surface desktop host:
Folders | Messages | Message.  It uses only `wire_renderer.h`; GTK remains
private to the renderer.  The message collection advertises 200,000 rows while
the renderer requests only the first bounded 100-row window.

## v0.1-dev28 — native MailReader row projection

The GTK4 renderer now projects the existing renderer-neutral `WireListRow` fields as a native desktop mail row (`From | Subject | Date`) while retaining stable application identity on the row. `wire_mailreader_demo` is now a normal GTK build target when GTK4 is installed. The host remains completely free of GTK APIs and still asks for only 100 rows from a 200,000-message backing collection.

## v0.1-dev29 — visible MailReader composition and native semantic round trip

The GTK qualification host now composes the MailReader as three renderer-neutral panes with visible `Folders`, `Messages`, and `Message` headings.  The message list remains a 100-row window over a 200,000-message source.  Activating a native GTK message row is translated by the private renderer into `messages.SelectionChanged(identity=...)`; the host responds only through the public Wire ABI by changing the semantic `message` document value.  Thus even the visible interactive demonstration does not acquire a GTK callback, widget pointer, or GTK include.  Generic `width` and `height` window properties are also projected privately by GTK rather than exposing toolkit sizing APIs to the application host.

## v0.1-dev30 — declarative UI loading

MailReader is no longer constructed in C. `wire_mailreader_demo` loads the semantic UI tree from either `examples/mailreader/mailreader.xml` or `examples/mailreader/mailreader.wire` through the renderer-neutral `wire_ui_loader` module. The host supplies named application sources and semantic event handling only. Layout hints (`orientation`, `position`, `expand`, preferred `width`/`height`) remain semantic input; GTK translates them privately.

Run the XML definition by default, or pass the Wire definition explicitly:

    build/wire_mailreader_demo examples/mailreader/mailreader.xml
    build/wire_mailreader_demo examples/mailreader/mailreader.wire
