# ooRexx Intention Service v0.1-dev11

A provider-neutral intention dispatcher for ooRexx.  It accepts user input, asks
providers what the user appears to mean, applies bucket-specific specificity policy,
asks for missing details, confirms the selected intention, and only then exposes the
registered event for dispatch.

The core rule is:

> recognition confidence is not permission to proceed.

An LLM may be very confident that a caller means `FORMAT`, but a destructive-command
bucket can still require an exact explicitly supplied device before the intention is
confirmable or dispatchable.

## Owned NLP engines

IntentionService owns the NLP recognition layer.  The package ships and qualifies
the complete swappable engine family under `src/nlp/`:

- FST / WFST
- Symbolic
- Contrastive exemplar
- Probabilistic LM
- Online perceptron
- Calibrated LM
- Hyperdimensional / VSA
- Decision list
- Ripple-down rules
- Analogical modeling
- META ensemble

Applications select them through the service boundary rather than constructing parser
classes directly:

```rexx
service = .IntentionService~new
service~useNlp("META")
```

The simple `register("have dinner", event)` form derives `have` / `dinner` as the
initial semantic verb/noun terms.  Domain code can supply richer vocabulary without
knowing the selected engine:

```rexx
service~register("have dinner", event)~semantics("have|eat", "dinner|meal")
```

All owned engines receive the same registrations and produce the same route contract.
The previous external `SymbolicNLP` dependency has been removed.

## Minimal API

```rexx
service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)
service~register("have dinner", event)

decision = service~input("I fancy some food")
/* CONFIRM / CLARIFY / UNKNOWN */

decision = service~input("yes")
if decision~status == "READY" then service~dispatch(decision)
```

## Buckets and corpus

Buckets group both dispatchable intention registrations and non-dispatchable evidence material. Typical buckets include:

- `COMMANDS` — valid commands and usage language;
- `POLICY` — policy files/text used as interpretation evidence;
- `DESTRUCTIVE_COMMANDS` — commands requiring explicit operational detail;
- application/domain-specific vocabulary buckets.

Arbitrary corpus evidence can be fed independently of events:

```rexx
service~registerBucket("POLICY", policyBucketPolicy)
service~feed("POLICY", policyText, "storage-policy.conf")
```

Providers can inspect these buckets. The bundled LLM provider includes bounded corpus evidence in its classification prompt; deterministic providers are free to ignore evidence they do not need.

```rexx
service~registerBucket("COMMANDS", -
    .IntentionBucketPolicy~new("FLEXIBLE", 55, 12, .true, .false))

service~registerBucket("DESTRUCTIVE_COMMANDS", -
    .IntentionBucketPolicy~new("EXPLICIT", 75, 8, .true, .false))

formatReg = service~register("format drive", formatEvent, "DESTRUCTIVE_COMMANDS")
formatReg~requireSlot("DEVICE", "Which exact device should be formatted?", .true)
formatReg~slotRule("DEVICE", "DRIVE|DEVICE|DISK", "NEXT")
```

Thus `show files please` can resolve flexibly, while `format drive` remains in
`CLARIFY` until the required target is explicit. If the caller answers only `/dev/sdb`,
the service retains the unresolved request, folds the clarification back into it, and
re-evaluates. It does not force the caller to repeat the command.

`IntentionCorpus`, `IntentionCorpusMaterial`, and `IntentionCorpusEvidence` provide a
bulk-loading seam for material assembled elsewhere. A corpus may therefore contain
both executable intention descriptions and supporting files/text such as policy.
Material stays separated by bucket and acquires the bucket's policy when loaded.

## Providers

Providers only produce `IntentionProposal` objects. They do not dispatch events and
do not get to override bucket policy.

Included provider surfaces include:

- `DeterministicIntentionProvider` — phrase/alias matching plus deterministic slot rules;
- `NLPIntentionProvider` — adapter over the NLP family owned and shipped by IntentionService;
- `SymbolicNLPIntentionProvider` — compatibility adapter for callers holding an already configured symbolic parser;
- `LLMIntentionProvider` — model-neutral adapter.

The swappable NLP family is owned by IntentionService under `src/nlp/`. `service~useNlp("META")` is the normal application surface; applications do not construct or lifecycle-manage the owned parsers themselves.

### LLM usage

The intention layer does not know or care which model is underneath. The supplied LLM
object has one tiny contract: `complete(prompt)` returns classification text.

```rexx
service~registerProvider( -
    .LLMIntentionProvider~provider(.MyFancyNewLLM~new))
```

A project-specific LLM adapter can wrap OpenAI-compatible, Ollama, Gemini, Mistral,
watsonx or any future implementation without changing `IntentionService`.

## Specificity policy

`IntentionBucketPolicy` supports:

- `FLEXIBLE` — semantic/alias matching can resolve the intention;
- `EXPLICIT` — the operation itself must have explicit evidence;
- `EXACT` — requires a score of 100 as well as all required slots.

Each registration can declare required slots. Each requirement can demand that its
value be explicit rather than inferred. Bucket policy decides whether inferred values
may satisfy required slots; the default is **no**.

This is specifically intended to distinguish low-risk operations such as directory
listing from destructive operations such as formatting a device.

## State machine

`input(text)` returns an `IntentionDecision` with one of:

- `UNKNOWN` — no acceptable interpretation;
- `CLARIFY` — ambiguity or missing specificity remains;
- `CONFIRM` — enough information exists; caller must confirm meaning;
- `READY` — confirmed and dispatchable.

`dispatch()` rejects every state except `READY`.


## Typed clarification slot resolution

Dev5 generalises clarification replies into semantic slot resolution. A required slot
may declare a semantic type, and the service may register one resolver for that type:

```rexx
registration~requireSlot("CUSTOMER", "Which customer?", .true)
registration~slotType("CUSTOMER", "CUSTOMER_REF")
service~registerSlotResolver("CUSTOMER_REF", customerResolver)
```

When a CLARIFY decision is waiting for that slot, the next utterance is offered to
the resolver before it is concatenated back into the original sentence. A resolver
returns zero, one, or many canonical binding candidates:

- zero: remain in CLARIFY; raw text is not silently accepted as the slot value;
- one: bind the canonical slot value(s), then re-run bucket policy;
- many: reuse the ordinary numbered clarification-choice contract, so one state
  machine handles ambiguous intentions and ambiguous entity references.

This is deliberately domain-neutral. Database rows, product/customer references,
class names, devices, hosts, accounts, aliases, and other domains can all register
typed resolvers without adding special cases to IntentionService. Resolver logging
uses `INTENTION.SLOT.RESOLVE.START`, `.RESULT`, `.NONE`, `.BOUND`, and `.AMBIGUOUS`.

## Proposed plans

An intention proposal may carry a structured plan describing what the provider or
domain adapter proposes to do **if that meaning is accepted**.  A plan is conditional
evidence only: it does not bypass bucket policy, clarification, confirmation, or the
`READY` dispatch gate.

```rexx
plan = .IntentionPlan~new("SEARCH_ORDERS_FOR_CUSTOMER", -
    "Resolve the customer and query matching orders")
plan~sideEffectClass = "READ_ONLY"
plan~requireBinding("CUSTOMER")
plan~addStep("RESOLVE_ENTITY", "Resolve customer reference", "CUSTOMER")
plan~addStep("DATABASE_QUERY", "Query orders for resolved customer", "ORDERS")
proposal~proposedPlan(plan)
```

Plans are preserved through multi-option clarification, so each candidate meaning may
show a different conditional plan.  `IntentionDecision~proposedPlan` and
`IntentionClarificationChoice~proposedPlan` expose the structured plan directly to
terminal, Desk, or other UI code.

For plans that depend on canonical clarification bindings, attach a domain-owned plan
builder to the registration:

```rexx
registration~planBuilder(myPlanBuilder)
```

The builder contract is `build(service, registration, proposal) -> plan`.  Intention
Service invokes it when proposals enter the service and again after slot resolution,
so a plan is refreshed after (for example) `Alice -> customer_id=1`.  Intention
Service does not invent SQL, shell commands, or other domain steps itself.

`IntentionPlan` provides structured steps, required bindings, expected outputs,
authority requirements, side-effect classification, evidence, and metadata.  These
fields are also surfaced in structured intention logging where applicable.


## Plan feasibility assessment

Dev7 separates **meaning understood** from **plan presently feasible**.  A structured
`IntentionPlanAssessment` is attached to an `IntentionPlan` after plan materialisation.
The built-in baseline checks required canonical bindings; a domain can register an
assessor on the intention registration:

```rexx
registration~planAssessor(myAssessor)
```

The assessor contract is:

```text
assess(service, registration, proposal, plan, baselineAssessment) -> assessment
```

Assessments report `UNKNOWN`, `FEASIBLE`, or `INFEASIBLE` plus structured missing
bindings, unavailable resources, missing authority, violated preconditions, evidence,
and metadata.  `IntentionDecision~planAssessment` exposes the result and
`planExecutable` is true only for `FEASIBLE`.  Clarification choices preserve their
individual assessments.

Plan feasibility is deliberately **not authority**.  Marking a plan FEASIBLE cannot
bypass bucket policy, explicit-slot rules, confirmation, or the `READY` gate, and a
listed authority requirement is not assumed to be held.  Domain assessors must report
known missing authority explicitly.  Assessment is rerun whenever the plan is rebuilt
after canonical slot resolution, preventing stale feasibility conclusions.

## Runtime qualification

A full environment test is included:

```bash
OOREXX_DEB=/path/to/oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb \
  ./tools/test_environment.sh
```

The script extracts that package without installing it system-wide, verifies revision
`13196`, sets the package `REXX_PATH`, and runs every test in the real ooRexx runtime.

## Files

- `src/IntentionService.cls` — registry, buckets, policy, decision loop, corpus, dispatch.
- `src/IntentionProviders.cls` — deterministic, Symbolic NLP and LLM providers.
- `src/nlp/` — IntentionService-owned NLP engine family.
- `tests/` — core, bucket-policy and LLM-provider tests.
- `examples/bucketed_dispatch.rex` — interactive example.
- `tools/test_environment.sh` — ooRexx 5.3.0 r13196 environment qualification.
- `docs/DESIGN.md` — architecture and invariants.
## dev3 — instrumentation, implication, learned paths and language spheres

Dev3 adds four selection/evidence layers without weakening bucket policy:

- the owned FST engine is always used as the fixed approved-form fast path;
- session implication resolves explicit references such as `do it again` from the previously dispatched intention and its slots;
- `IntentionPathLearner` records successful intention paths and can predict the next intention when a later run matches a previously learned prefix;
- language/domain spheres can be registered with an existing language specification and an interrogator object.

Path prediction is evidence, not authority. `predictNext()` returns candidates. `next`, `continue`, `what next` and `then` may admit those candidates into normal selection, after which ordinary bucket specificity/confirmation policy still applies.

Typical sequence:

```rexx
service~beginPath
/* dispatch REMOVE_TREE, MAKE_DIRECTORY, LIST_DIRECTORY, UNZIP_ARCHIVE ... */
service~sealPath     /* retain this successful procedural episode */

service~beginPath
/* after the same prefix on a later run: */
predictions = service~predictNext
```

`do it again` uses the session history stack rather than the path predictor. It repeats the last dispatched intention and carries the previous slot values forward as inherited evidence.

### Logging

IntentionService does not invent a private logging framework. Supply the existing ooRexx Logging `LogService` (or any compatible object) with:

```rexx
service~logger(logService)
```

The service emits structured `Directory` payloads through the established contract:

```rexx
logService~log(level, payload, point)
```

Current instrumentation points include:

- `INTENTION.INPUT`
- `INTENTION.SELECT`
- `INTENTION.CLARIFY`
- `INTENTION.AMBIGUOUS`
- `INTENTION.CONFIRM`
- `INTENTION.CONFIRM.ACCEPT`
- `INTENTION.CONFIRM.REJECT`
- `INTENTION.READY`
- `INTENTION.POLICY.BLOCK`
- `INTENTION.DISPATCH`
- `INTENTION.PATH.BEGIN`
- `INTENTION.PATH.LEARN`
- `INTENTION.PATH.PREDICT`
- `INTENTION.SPHERE.SELECT`
- `INTENTION.INTERROGATOR.START`
- `INTENTION.INTERROGATOR.EVIDENCE`

### Language/domain spheres and interrogators

A sphere combines an authoritative specification with an interrogator:

```rexx
profile = semanticSourceLanguageService~profile("oorexx")
service~registerSphere("OOREXX", profile, oorexxInterrogator)
service~registerSphere("PYTHON", pythonProfile, pythonInterrogator)
service~registerSphere("BASH", bashSpec, bashInterrogator)
service~registerSphere("DATABASE", databaseSpec, databaseInterrogator)
```

For an input such as:

```text
from database show records with LLM as EDITOR
```

IntentionService selects the `DATABASE` sphere, gathers corpus records tagged for that sphere/language, constructs an `IntentionSituation`, and calls:

```rexx
interrogator~interrogate(situation)
```

The situation contains the original input, sphere-stripped body, specification, relevant records, session history and registered intentions. The interrogator may return `IntentionProposal` objects directly or an `IntentionInterrogationResult` containing proposals plus purpose/evidence. This lets the interrogator infer that records indicate `DISPLAY` rather than `EDIT`, for example, while IntentionService still applies the bucket's specificity rules before dispatch.

The existing `SemanticSourceLanguageService` remains the authority for source-language profiles such as ooRexx and Python; IntentionService consumes those profile objects rather than copying their language rules.

## dev3 qualification

The complete package test harness has been executed against the supplied exact runtime:

```text
Open Object Rexx Version 5.3.0 r13196 - Internal Test Version
```

All current tests pass, including owned NLP engines, corpus/bucket policy, LLM provider contract, session implication/path learning/logging and language-sphere interrogation.

## dev4 — bounded multi-option clarification

Ambiguity is not a binary `X or Y` contract. Dev4 retains a bounded ranked candidate set and returns it as structured clarification choices. The default bound is seven and can be changed with:

```rexx
service~setMaxClarificationOptions(5)
```

A clarification decision therefore carries both a printable question and machine-readable choices:

```text
Did you mean:

[1] CLASS: HOUSE METHOD: OPEN_WINDOW
[2] CLASS: HOUSE METHOD: OPEN_DOOR
[3] CLASS: HOUSE ATTRIBUTE: WINDOW
```

Applications may render `decision~question` directly or build semantic buttons from `decision~choices`. Each `IntentionClarificationChoice` exposes the stable index, intention id, label, score, provider and evidence. A reply such as `3` resolves the retained choice without asking Luna or another controller to reconstruct the ambiguity. Free-form clarification still folds back into the unresolved input and is re-evaluated by IntentionService.

Registration labels are owned by the intention registry. `CLARIFICATION_LABEL` may be supplied explicitly; otherwise the service derives a label from standard registration metadata such as `SPHERE`, `LANGUAGE`, `CLASS`, `METHOD`, `ATTRIBUTE`, `OPERATION`, `OBJECT`, and `ROLE`, finally falling back to the canonical phrase.

Equal-score candidates now retain deterministic first-seen order during consolidation so numbered options are stable. Structured logging for `INTENTION.AMBIGUOUS` includes the complete bounded `OPTIONS` array, and `INTENTION.AMBIGUOUS.SELECT` records the selected index and intention.

## dev4 qualification

The exact supplied runtime was used:

```text
Open Object Rexx Version 5.3.0 r13196 - Internal Test Version
```

All tests pass, including the new three-way ambiguity, numeric selection, invalid-selection retention, semantic labels and bounded-option regression.


## dev8 — intention hints and semantic plan dependencies

Dev8 adds advisory `IntentionHintLibrary` support. A hint may carry bounded phrase hints and conditional plan hints, optionally scoped to a language/domain sphere. Phrase hints can propose or bias a registered intention; plan hints are merged into the selected proposal without granting authority or replacing bucket policy/domain plan builders. Plan-only hints may shape a plan for an already-recognised intention without manufacturing recognition.

`IntentionPlanStep` now supports stable step IDs and `dependsOn()` dependencies. Plans retain declared order as evidence while `executionSteps()` returns deterministic dependency order. Duplicate IDs, missing dependency targets and cycles fail validation and therefore plan feasibility.


## dev9 — shared evidence and evidence-backed plan requirements

Dev9 generalises the evidence pattern exposed by coding, database and NotNotes
consumers so each application does not invent its own confidence/source/authority
records and post-READY feasibility gate.

`IntentionEvidenceFact` is the common fact envelope:

- `subject`
- `predicate`
- `value`
- `confidence` (0..100)
- `source`
- `authority` (`ADVISORY`, `INFERRED`, `ASSERTED`, `CONTRACT`, `OBSERVED`, `AUTHORITATIVE`)
- `provenance`
- optional `observedAt` and metadata

Confidence and evidential authority are independent.  A user hint can be recorded
with confidence 100 while remaining advisory; a runtime observation can satisfy a
plan requirement that demands OBSERVED evidence.  `IntentionService~bestEvidence`
selects the strongest matching retained fact by authority then confidence without
discarding weaker provenance.

Facts may be held in the service evidence ledger, on a proposal, or on a proposed
plan. `IntentionEvidenceRequirement` lets a plan state the evidence it requires,
including minimum confidence and minimum authority.  Unsatisfied evidence becomes
a plan-assessment precondition blocker.  Requirements may optionally provide a
clarification question; in that case IntentionService itself returns `CLARIFY`
instead of requiring an application/controller to create a second clarification
state machine.

External interrogation may change evidence while a clarification is retained.
`service~refreshActiveDecision` rematerialises/reassesses the retained proposal
without consuming another utterance.  This is the intended bridge after runtime,
database, registry or other authoritative interrogation publishes new facts.

Evidence and feasibility remain non-authoritative for dispatch: they do not bypass
bucket policy, explicit-slot requirements, confirmation, or the normal READY gate.


## dev10 — discovery freshness and clarification escape

Domains may register discovery providers whose `discover(service)` method returns an `IntentionDiscoverySnapshot(source, revision)`. Fresh proposal cycles replace the prior discovery evidence set atomically, retain persistent evidence separately, and stamp proposals/decisions with the current discovery generation. This supports live MVS, spreadsheet, compute and management surfaces without turning startup catalogues into permanent truth. `refreshActiveDecision()` re-runs a retained intention when its discovery generation has changed.

Pending clarification can be abandoned through `service~inputNew(text)`, `NEW INTENT ...`, `NEW REQUEST ...`, `START OVER ...`, or explicit cancellation. This prevents an unrelated request from being silently consumed as an answer to an old clarification.


## dev11 — plan transformations, contradiction-preserving evidence, transient intention surfaces

Dev11 generalises three patterns observed independently in current intention consumers.

### Conversational plan transformations

Applications may register plan transformers with `registerPlanTransformer()`. A transformer receives the latest dispatched intention/plan and a follow-up utterance, and may return an `IntentionPlanTransformation`. Transformations change only declared dimensions; all unspecified plan metadata, steps and bindings are retained. This supports follow-ups such as “only pending”, “same for Jane”, “sort that by date” without creating a second application-owned conversation state machine.

### Evidence sets and contradictions

`IntentionEvidenceSet` retains all facts for a subject/predicate and exposes contradiction groups rather than collapsing them to one winner. `bestEvidence()` remains available as an intentional convenience query. Evidence requirements may additionally constrain source, minimum agreeing fact count, and whether unresolved contradiction is permitted. Confidence and evidential authority remain independent.

### Discovery-scoped intention surfaces

`IntentionDiscoverySnapshot` may advertise `IntentionSurfaceAdvertisement` objects. An advertisement carries a generic provider plus source object, relationship, scope, lifetime and authority metadata. The active surface set is replaced on each discovery refresh; when the related object/service disappears, the specialist surface disappears with it. IntentionService has no knowledge of network transports, database engines, management providers or other domain-specific mechanics.
