# Intention Service design

## Responsibilities

`IntentionService` owns conversational state, candidate arbitration, clarification,
confirmation and dispatch. It never performs NLP itself.

An `IntentionProvider` proposes an intention plus confidence/evidence/slots. Providers
may be deterministic, symbolic NLP, statistical NLP, LLM-backed, or domain-specific.
Provider output is advisory.

An `IntentionBucket` groups registrations sharing operational interpretation policy.
Its `IntentionBucketPolicy` is authoritative for the amount and provenance of detail
required before a proposal may advance.

## Invariants

1. A provider never dispatches an event.
2. A high confidence score never bypasses required slot policy.
3. Explicit-required slots are not satisfied by inferred values unless the bucket
   explicitly opts into that behavior.
4. `dispatch()` accepts only a `READY` decision.
5. A `READY` decision can only result from explicit caller confirmation unless the
   bucket deliberately disables confirmation.
6. Provider-specific model/vendor details never enter the service contract.
7. Existing NLP implementations are adapted, not duplicated.

## Corpus model

Corpus material is intentionally broader than commands. A deployment can maintain
separate buckets for command grammar, policy, risky operations, help text, application
vocabulary, customer-service intents, or any other evidence source.

Buckets hold two related things: dispatchable registrations and arbitrary evidence.
`feed()` adds evidence without manufacturing an event or fake intention. Providers can
consult that evidence while proposing meaning; bucket policy still independently
controls whether the resulting proposal is specific enough to proceed.

The corpus object loads both intention material and evidence into the runtime registry.
Later storage/index/search implementations can feed the same contract without changing
the service.

## Safety specificity

A formatting command demonstrates why recognition and permission are separate:

```text
input: "format drive"
provider: FORMAT_DRIVE, confidence 100
bucket: DESTRUCTIVE_COMMANDS / EXPLICIT
required explicit slot: DEVICE
result: CLARIFY "Which exact device should be formatted?"
```

Only after the caller supplies the target and confirms the resolved intention can the
decision become `READY`.


## NLP ownership boundary

NLP classification is part of intention resolution and is therefore owned by this
package. `IntentionNLPRegistry` is the stable construction boundary. Applications may
select a strategy, but do not own parser lifecycle, registration replication, file
layout, or ensemble composition. The provider bridge rebuilds an engine when the
service registration signature changes so aliases and semantic vocabulary remain in
sync with the authoritative IntentionService registry.


## Bounded ambiguity sets (dev4)

Ambiguity is an N-way candidate-set state, not a binary branch. IntentionService owns the ranked set, bounds its presentation, and retains it in the active `CLARIFY` decision. Numeric selection addresses that retained set directly; free-form clarification is folded into the unresolved request and re-evaluated. Applications must not maintain a parallel clarification state machine.

`IntentionClarificationChoice` is the UI-neutral projection of one candidate. Stable ordering is part of the contract: equal-score proposals preserve their first-seen order after consolidation. Bucket policy remains authoritative after a candidate is selected, so choosing an option cannot bypass required explicit slots, specificity, or confirmation.

## Typed slot resolution

Clarification is not string concatenation when the pending requirement names a
resolvable semantic entity. `IntentionRegistration~slotType()` associates a slot
with a semantic type. `IntentionService~registerSlotResolver()` associates that type
with a domain resolver. The resolver receives the service, registration, current
proposal, pending requirement and clarification answer and returns
`IntentionSlotResolution` containing zero, one or many
`IntentionSlotResolutionCandidate` objects. Candidates may bind one or several
canonical slots.

A unique candidate is rebound into a copied proposal and passes through the normal
bucket policy. Multiple candidates become ordinary `IntentionClarificationChoice`
objects. Therefore the service has one clarification state machine rather than a
separate entity-resolution dialogue system.


## Conditional proposed plans

Providers may attach an `IntentionPlan` to an `IntentionProposal`.  Registrations may
alternatively register a domain-owned plan builder.  Plans describe the work that
would follow *if* the proposed meaning is accepted; they never grant execution
authority.

Plan materialisation is deliberately downstream of semantic proposal creation and is
repeated after canonical slot binding.  This prevents stale plans from surviving a
clarification such as a human-readable entity name being resolved to an authoritative
identifier.  Ambiguity choices retain their individual plans, allowing a UI to show
meaning and consequence together before selection.

The dispatch invariant is unchanged: only a `READY` decision may invoke the registered
event.


## Plan assessment and feasibility (dev7)

Meaning selection and plan feasibility are separate axes.  Plan materialisation is
followed by a structural baseline assessment of required bindings and, when registered,
a domain-owned plan assessor.  The assessor may consult authoritative application
state and report unavailable resources, missing authority, violated preconditions and
evidence.  It does not alter recognition confidence or grant execution authority.

An assessment has one of three states: `UNKNOWN`, `FEASIBLE`, or `INFEASIBLE`.
Any structured blocker normalises the state to `INFEASIBLE`.  Required authority on
the plan is a declared requirement only; authority is missing only when authoritative
domain evidence says so.

Assessments travel with plans through clarification choices, confirmation and READY
decisions, and are refreshed after canonical slot resolution.  Consequently a caller
can distinguish "this is what you mean" from "this conditional plan can currently be
carried out" without introducing a second interpretation state machine.  The existing
READY/dispatch invariant remains unchanged.


## Intention hints

`IntentionHintLibrary` is an advisory library of recurring recognition/planning patterns. A hint targets a registered intention and may contain phrase hints, a partial structured plan, an optional sphere scope, and evidence. Phrase hints can propose that meaning with bounded confidence. Plan hints are merged only after a meaning has been proposed/selected and cannot create dispatch authority. A plan-only hint (`planAlways(.true)`) can shape an already-recognised intention without manufacturing recognition.

Hints deliberately preserve the authority split: they are evidence. Bucket specificity, slot resolution, confirmation, plan feasibility and the READY dispatch gate remain authoritative. Structured log points `INTENTION.HINT.PHRASE` and `INTENTION.HINT.PLAN.APPLY` expose their contribution.

## Semantic plan dependencies

`IntentionPlanStep` supports a stable `id()` and zero or more `dependsOn()` relationships. `IntentionPlan~steps` preserves declared/conversational order; `executionSteps()` returns deterministic topological order. `validate()` rejects duplicate IDs, missing dependency targets and cycles. Structural plan failures feed plan assessment as violated preconditions; they do not rewrite the recognised meaning.


## Shared evidence contract (dev9)

Hints, evidence and authority are distinct concepts:

- a hint is an advisory pattern/suggestion;
- an evidence fact is a structured claim/observation with source, confidence,
  evidential authority and provenance;
- operational authority remains governed separately by bucket/plan policy.

Plans may declare evidence requirements.  Assessment considers facts from the
service ledger, the proposal and the plan.  A requirement can demand both a
confidence threshold and an evidence-authority threshold.  This allows the same
contract to represent runtime observation, language/library contracts, database
truth, device inventories, document stores, cloud state and advisory user hints.

A missing evidence requirement can be merely infeasible, or it may carry an
explicit clarification question.  Only the latter creates interaction state.
`refreshActiveDecision()` exists for evidence that changes asynchronously with
respect to user text, such as a completed runtime interrogation.
