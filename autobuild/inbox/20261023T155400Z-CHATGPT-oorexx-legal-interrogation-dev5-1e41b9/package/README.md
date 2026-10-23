# ooRexx Legal Interrogation v0.1-dev5

A model-neutral, clause-by-clause interrogatory authoring layer upstream of Legal Effect, with dynamic intention negotiation, source-document intake seams, revision-bound compile handoffs, and a concrete Intention Service v0.1-dev11 dynamic-discovery bridge.

The component preserves the original source object, exact clause text and evidence; dynamically exposes the next authoring intention; records candidate propositions and proposition tests; requires a separate review/challenge step before an answer enters the accepted legal record; performs document-wide reconciliation; and produces a deliberately non-authoritative compile handoff.

It does **not** replace Legal Effect, Institutional Policy, `LegalRuleCompiler`, `LegalEffectEngine`, or Intention Service. It does **not** turn an LLM answer into authority.

## dev5

`dev5` closes the dev11 freshness and repository-qualification gap discovered while reconciling the live Alchemy GitHub estate:

- discovery snapshot revision now derives from the legal session authoring revision and closure state, not the port's call counter;
- repeated discovery of unchanged legal state therefore leaves Intention Service's own discovery generation unchanged;
- an authoring mutation advances the session revision and causes Intention Service to advance its discovery generation on the next refresh;
- `tests/test_intention_service_dev11_live.rex` binds the adapter to the actual sibling `oorexx_intention_service` v0.1-dev11 package and checks its real `refreshDiscovery()`, `discoverySnapshots`, `discoverySurfaces`, advertisement generation stamping, READY execution and stale-surface rejection;
- `run_tests.sh` and `integration.json` make the package a first-class Alchemy Autobuild submission without vendoring Intention Service.

The service-level `IntentionSurfaceAdvertisement~discoveryGeneration` is the authoritative Intention Service generation. `LegalInterrogationDev11SurfaceSubject~discoveryGeneration` remains the local Legal Interrogation discovery-cycle value for compatibility and is not used as Intention Service authority.

## dev4

`dev4` rebases the Intention boundary onto the current Library's **Intention Service v0.1-dev11** public dynamic-discovery pattern without vendoring the service:

- `LegalInterrogationDev11DiscoveryProvider` returns an `IntentionDiscoverySnapshot` on every discovery refresh;
- every currently available mandatory/query operation becomes an `IntentionSurfaceAdvertisement`;
- advertisements retain the exact live `LegalInterrogationSession`, operation, subject reference, discovery generation and session revision;
- `LegalInterrogationDev11SurfaceProvider~executeReady()` requires an Intention decision whose status is exactly `READY`;
- every surface fails closed as `STALE_DISCOVERY` if the interrogation revision changes after discovery;
- discovery advertisements are marked `ADVISORY`: availability is not legal authority or permission to mutate;
- structured legal payloads remain full Rexx objects and are never reconstructed from free text inside this adapter;
- `LegalInterrogationIntentionServiceDev11Binding` requires the host service to expose `registerDiscoveryProvider(provider)` and otherwise fails closed;
- no Intention Service source is copied into this package.

This mirrors the current Library pattern in which specialist surfaces are refreshed each turn and Intention Service owns replacement/generation semantics. The older generation-neutral binding remains for deployments that deliberately supply another adapter. Dev4 also applies the current ooRexx standards rules to inherited internals while preserving the public `result` accessors and state-machine API.

## dev3

`dev3` adds:

- `LegalInterrogationDocumentPort` and `LegalInterrogationDocumentRequest` for admitting an original native source object without flattening it;
- source-native clause extraction through a host adapter (`extractLegalInterrogationClauses`) rather than a package-local parser assumption;
- monotonically increasing authoring revisions on intention-mediated mutations;
- detached clause/question/proposition/test snapshots in `LegalInterrogationCompileHandoff`;
- handoffs bound to the exact authoring revision and rejected as `STALE_HANDOFF` after later edits;
- `REOPEN_QUESTION`, which invalidates downstream clause propositions/tests and forces them through challenge/resolution again;
- explicit proposition supersession with retained retired history and no retired proposition in the active compile candidate set;
- revision numbers on negotiation records;
- fail-closed rejection of self-supersession and new tests against superseded propositions.

`dev2` added:

- `LegalInterrogationIntentionPort` — dynamic specialist-provider surface for Intention Service;
- `ANSWER_* -> REVIEW_* -> ACCEPT/REVISE/REJECT/REQUIRES_LEGAL_REVIEW` negotiation;
- retained answer and review histories;
- retained `LegalInterrogationNegotiationRecord` objects for each executed intention;
- explicit `TEST_LEGAL_PROPOSITION` route for questions such as “does X imply Z when A?”;
- generation-specific `LegalInterrogationIntentionBinding` adapter seam instead of guessing Intention Service constructors;
- `LegalEffectTestRequest` / `LegalEffectTestPort` for applying named tests through the real Legal Effect runtime;
- validation that unknown answer dispositions, review decisions and Legal Effect test names fail closed.

## Public API

Core classes:

- `LegalInterrogationSession`
- `LegalInterrogationClause`
- `LegalInterrogationQuestion`
- `LegalInterrogationAnswer`
- `LegalInterrogationAnswerReview`
- `LegalInterrogationProposition`
- `LegalPropositionTest`
- `LegalInterrogationDirector`
- `LegalInterrogationIntentionProvider`
- `LegalInterrogationCompileHandoff`

Intention/test-port classes:

- `LegalInterrogationIntentionPort`
- `LegalInterrogationIntentionSurface`
- `LegalInterrogationNegotiationRecord`
- `LegalInterrogationPropositionDraft`
- `LegalInterrogationPropositionResolution`
- `LegalInterrogationTestDraft`
- `LegalInterrogationTestResolution`
- `LegalInterrogationIntentionBinding`
- `LegalEffectTestRequest`
- `LegalEffectTestPort`
- `LegalInterrogationDocumentRequest`
- `LegalInterrogationDocumentPort`
- `LegalInterrogationQuestionSnapshot`
- `LegalInterrogationPropositionSnapshot`
- `LegalInterrogationTestSnapshot`
- `LegalInterrogationClauseSnapshot`
- `LegalInterrogationSupersessionRequest`
- `LegalInterrogationDev11SurfaceSubject`
- `LegalInterrogationDev11SurfaceProvider`
- `LegalInterrogationDev11DiscoveryProvider`
- `LegalInterrogationIntentionServiceDev11Binding`

Artifact API remains `legal.interrogation/0.1`; dev5 is an additive Intention Service freshness/qualification increment.

## Host boundaries

The Intention Service package is deliberately not vendored. For the current Library baseline, `LegalInterrogationIntentionServiceDev11Binding~bind()` uses the observed public dev11 contract:

```text
intentionService~registerDiscoveryProvider(provider)
provider~discover(service) -> IntentionDiscoverySnapshot
                           -> IntentionSurfaceAdvertisement[]
```

The advertisements are live specialist surfaces only. A selected operation still requires the host Intention controller to produce `READY`, after which `executeReady()` checks the captured session revision before forwarding the structured payload into `LegalInterrogationIntentionPort`.

The older `LegalInterrogationIntentionBinding` generation-neutral seam remains available for another Intention generation or host-specific registration strategy.

Likewise, `LegalEffectTestPort~evaluate()` calls a host adapter implementing:

```text
evaluateLegalEffectTest(request)
```

The port validates the requested operation but never evaluates legal effect itself.

## Run

With ooRexx on PATH:

```sh
REXX_PATH="$PWD/src" rexx tests/test_legal_interrogation.rex
REXX_PATH="$PWD/src" rexx tests/test_intention_port.rex
REXX_PATH="$PWD/src" rexx tests/test_lifecycle.rex
REXX_PATH="$PWD/src:$PWD/tests" rexx tests/test_dev11_discovery.rex
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service ./run_tests.sh
```

Or run the complete environment qualification against an ooRexx `.deb` without system installation:

```sh
./test_environment.sh /path/to/oorexx-5.3.0-13196...deb
```
