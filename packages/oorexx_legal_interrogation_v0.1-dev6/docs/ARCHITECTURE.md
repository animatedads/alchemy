# Legal Interrogation v0.1-dev6 architecture

## Core invariant

**A model may propose legal meaning; it may not silently promote its proposal to legal effect.**

Legal Interrogation is an authoring/cross-examination layer. Legal Effect remains the deterministic legal authority engine and Intention Service remains the recognition/clarification/plan authority for conversational routing.

## Pipeline

```text
authoritative/native source object
        |
        v
LegalInterrogationSession
        |
        +-- dynamic Intention discovery
        |
        +-- clause question
        |      |
        |      +--> LLM/reviewer proposes answer
        |      |
        |      +--> separate REVIEW intention
        |              ACCEPT / REVISE / REJECT / LEGAL_REVIEW
        |
        +-- candidate proposition
        |      |
        |      +--> source-support / condition / exception challenge
        |      +--> converse / necessity / sufficiency / falsification challenge
        |      +--> explicit proposition tests
        |
        +-- document-wide reconciliation
        |
        v
LegalInterrogationCompileHandoff  [authoritative=false]
        |
        +--> host legal.effect adapter
        v
LegalCompileProposal / LegalCompilationUnit
        v
LegalRuleCompiler
        v
sealed LegalRuleGeneration
        v
LegalEffectEngine
```

The existing Legal Effect compiler boundary is not weakened. Legal Interrogation does not create a compiler certificate, sealed rule generation or executable disposition.

## Full-object retention

The Rexx object is carried, not flattened:

- `LegalInterrogationSession~sourceObject` retains the source object;
- `LegalInterrogationClause~sourceObject` retains the clause/source object;
- evidence links retain source objects;
- intention payloads are retained on negotiation records;
- `LegalEffectTestRequest` retains the legal artifact, proposed action, context, assertion and evidence objects.

Serialization/projection belongs outside this semantic boundary.

## Dynamic Intention negotiation

`LegalInterrogationIntentionPort~discover(session)` re-evaluates the current session every time it is called. It does not cache a permanent action catalogue.

For an unanswered clause question the next mandatory intention is:

```text
ANSWER_EXPLAIN_CLAUSE
```

After a proposer supplies an answer the next discovery becomes:

```text
REVIEW_EXPLAIN_CLAUSE
```

A reviewer may choose:

```text
ACCEPT
REVISE
REJECT
REQUIRES_LEGAL_REVIEW
```

`REVISE` or `REJECT` returns the question to the answer stage. `REQUIRES_LEGAL_REVIEW` fails closed and discovery becomes `REFER_LEGAL_REVIEW`.

This is the normal path for every required clause/challenge/reconciliation question. Direct `question~accept` remains for dev1 API compatibility but is not the intention-negotiated path.

## Clause interrogation

The base clause interrogation asks about neutral meaning, affected parties/capacity, legal-effect classification, trigger, conditions, exceptions, definitions, dependencies, compliance/breach consequences and unresolved semantic uncertainty.

The question set is a seed, not a claim that twelve questions exhaust legal interpretation. Proposition challenges add further questions from the live interpretation.

## Proposition interrogation

A candidate proposition cannot close merely because the proposing model states it confidently. `CHALLENGE_PROPOSITION` adds explicit source and logical challenge questions. Only after those questions have been answered and reviewed can `RESOLVE_PROPOSITION` become the next intention.

Explicit proposition tests are independent objects. For example:

```text
assertion:
    assignment(any party) -> supplier consent required

source proposition:
    assignment(non-affiliate) AND no_written_consent -> prohibited

result:
    CONTRADICTED
```

A contradicted *test assertion* does not mean the accepted proposition is contradicted; it records that the tested inference was too broad.

## Semantic uncertainty is not a missing runtime fact

If the uncertainty is about what source language means, it is semantic and blocks compilation. It must not be disguised as a runtime fact so that the Legal Effect engine appears to resolve an interpretation that was never established.

Once semantics are established and compiled, unknown transaction facts belong in Legal Effect. Legal Effect v0.14 counterfactual/sensitivity evaluation remains the correct place to ask what changes when a runtime fact/action assumption changes.

## Intention Service boundary

The current Library head is Intention Service v0.1-dev11. Its public dynamic-discovery pattern is now used directly rather than hidden behind a guessed private registration API:

```text
LegalInterrogationSession revision N
        |
        v
LegalInterrogationIntentionPort~discover()
        |
        v
LegalInterrogationDev11DiscoveryProvider~discover(service)
        |
        v
IntentionDiscoverySnapshot(provider/session, generation)
        |
        +--> IntentionSurfaceAdvertisement
        |       subject = exact session + operation + subjectRef + revision N
        |
        +--> IntentionSurfaceAdvertisement ...

next Intention turn -> discovery runs again -> service owns replacement
```

The advertisement itself is `ADVISORY`: it states that a specialist operation is currently available. It does not grant authoring or legal authority. A host controller must still obtain an Intention decision with status `READY`. `LegalInterrogationDev11SurfaceProvider~executeReady()` then checks that the session is still at the exact revision captured when the surface was discovered. If not, it returns `STALE_DISCOVERY` and the caller must rediscover.

This gives the intention boundary the same stale-state rule already applied to compile handoffs:

```text
discover at revision 17
       |
       +--> READY decision
       |
       +--> session changed to revision 18
       |
       v
execute old surface -> STALE_DISCOVERY
```

The dev11 bridge does not parse a free-text legal answer into a semantic payload. Full `LegalInterrogationAnswer`, review, proposition, test and supersession objects cross the boundary intact. Intention Service owns recognition/clarification/READY; Legal Interrogation owns the cross-examination state machine; Legal Effect remains the sole legal decision/compiler authority.

The earlier generation-neutral `LegalInterrogationIntentionBinding` remains as a compatibility seam for other hosts.

## Legal Effect test boundary

`LegalEffectTestPort` exposes named application tests without implementing them:

```text
APPLIES
PARTY_IS_BOUND
EFFECTIVE_AT
CONDITION_SATISFIED
EXCEPTION_APPLIES
OBLIGATION_SATISFIED
BREACH_EXISTS
AUTHORITY_EXISTS
CONFLICTS_WITH_HIGHER_AUTHORITY
REMEDY_AVAILABLE
ENFORCEABLE
REQUIRED_EVIDENCE
EFFECTIVE_DECISION
COUNTERFACTUAL
```

Unknown test names fail closed. The actual evaluation is delegated to the bound Legal Effect adapter, preserving Legal Effect as the single decision engine.

## Provenance

Each executed intention creates a `LegalInterrogationNegotiationRecord` containing the intention, subject, actor, full payload object, operation result and before/after closure state. Questions retain all proposed answers and all reviews rather than replacing history when an answer is revised.

These records are authoring provenance. They do not substitute for Legal Effect source-verification evidence, compiler certification, legal semantic identity or runtime-execution evidence.


## dev3 document intake and authoring lifecycle

The original document now has an explicit intake seam rather than assuming callers have already constructed a session:

```text
native source object (authority not implied by intake)
        |
        v
LegalInterrogationDocumentRequest
  sourceIdentity
  sourceObject            <-- retained Rexx object
  sourceLocator
  sourceEvidence[]        <-- retained evidence objects
        |
        v
LegalInterrogationDocumentPort~begin
        |
        v
LegalInterrogationSession
        |
        +--> host source adapter
        |      extractLegalInterrogationClauses(...)
        |          returns source-native LegalInterrogationClause objects
        |
        v
INGEST_CLAUSE through LegalInterrogationIntentionPort
```

The document port does not claim that a source is authoritative merely because it was supplied. Legal Effect source verification and source-authority verification remain distinct downstream authority claims.

### Revision-bound handoff

A compile handoff is no longer a view over the live authoring arrays. It captures detached projection snapshots:

```text
session revision 41
   |
   +-- clause snapshots
   |     +-- question/accepted-review snapshots
   |     +-- active proposition snapshots
   |     +-- superseded proposition audit snapshots
   |     +-- proposition-test snapshots
   |
   +-- reconciliation snapshots
   |
   v
LegalInterrogationCompileHandoff(revision=41)
```

If the session is later mutated through the intention port, its authoring revision advances. `handoff~emitWith(adapter)` then fails with `STALE_HANDOFF` rather than allowing an old interpretation to be compiled as though it were current.

This is deliberately separate from Legal Effect semantic identity. The authoring revision says which interrogated proposal state was handed off; Legal Effect remains responsible for verified compilation input, certification, sealing and legal semantic identity.

### Reopening accepted answers

An accepted answer can be deliberately reopened through `REOPEN_QUESTION`. Reopening a clause question invalidates the clause's active propositions and their tests:

```text
accepted question
      |
      +-- REOPEN_QUESTION
      v
OPEN question
      |
      +--> proposition state = STALE
      |       challengeSeeded = false
      |
      +--> attached proposition tests = STALE
      |
      +--> authoring revision increments
      |
      +--> prior handoff becomes stale
```

The proposition must then pass the structured challenge again and be explicitly resolved. Stale proposition tests must likewise be re-resolved. The package does not silently assume that the earlier reasoning remains valid after one of its accepted premises changes.

### Supersession

A reviewed interpretation may be replaced without deleting the history. `SUPERSEDE_LEGAL_PROPOSITION` links the old proposition to its replacement. Tests attached to the old proposition are retired with it.

The compile snapshot exposes active propositions and superseded propositions separately. Superseded material remains auditable but cannot leak into the active compile-candidate set. Self-supersession and creation of new tests against a superseded proposition fail closed.

## dev4 discovery freshness invariant

Dynamic discovery is not a cached menu. The subject of each dev11 advertisement records both `discoveryGeneration` and `sessionRevision`. The generation identifies the discovery pass; the session revision identifies the legal-authoring state from which the operation was derived. Only the latter is an execution freshness precondition. Re-running discovery without mutation may create a new generation while leaving both generations semantically current; any authoring mutation makes all earlier-revision surfaces stale.

Independent legal matters should normally use independent Intention Service session/controller instances. Current dev11 `reset()` semantics retain dispatched history, so `reset()` must not be treated as a new client/matter boundary. Genuine multi-turn examination of one legal matter may intentionally share service history.

## dev5: stable discovery revision

The Intention Service discovery signature is semantic state, not observation count.
`LegalInterrogationDev11DiscoveryProvider` therefore publishes a snapshot revision
formed from the `LegalInterrogationSession` authoring revision and closure state.
Calling `discover()` twice without a legal-state change may create fresh surface
objects, but it must not manufacture a new Intention Service discovery generation.
A mutation that advances the session revision does change the signature and causes
the service generation to advance on the next refresh.

The generation stamped by Intention Service onto each copied
`IntentionSurfaceAdvertisement` is the service-owned generation used for retained
decision freshness. The surface subject's older `discoveryGeneration` field is only
the Legal Interrogation port's local discovery-cycle counter and is not an authority
claim.


## dev6 concrete Legal Effect v0.14 compiler bridge

The earlier host adapter seam is now implemented for the accepted Legal Effect v0.14 compiler contract. The bridge does not weaken or duplicate Legal Effect authority.

```text
closed LegalInterrogationCompileHandoff
        |
        |  exact session revision, active propositions only
        v
LegalInterrogationLegalEffectV014Adapter
        |
        +-- require real LegalSourceIdentity
        +-- require identity~cryptographicallyVerified
        +-- require real NormativeSource
        +-- preserve source expressionId for every provision
        +-- verify every clause through LegalSourceVerifier
        +-- map only supported propositions
        +-- accept only existing LegalPredicate conditions/exceptions
        v
LegalCompilationUnit                  [still non-authoritative]
        |
        +-- LegalProvisionReference + LegalProvision
        +-- LegalCompileProposal(evidence = verified provision reference)
        v
LegalRuleCompiler~compile(unit)       [authority boundary]
        |
        v
LegalCompilationCertificate
        + sealed LegalRuleGeneration
        + publicationEligible = true
```

### Source verification is not semantic acceptance

Interrogation acceptance does not set Legal Effect verification state. A `LegalSourceIdentity` created with an asserted `VERIFIED` value but no verifier-issued evidence remains `cryptographicallyVerified = false` and the bridge rejects it as `LEGAL_SOURCE_VERIFICATION_REQUIRED`. Legal Effect's own `LegalSourceVerifier` must bind the source bytes first.

### Provision identity rule

Legal Effect v0.14 requires every provision reference to use the same `expressionId` as the verified source identity. This is not inferred from the clause id. Dev6 therefore carries `sourceIdentity~expressionId` unchanged into every `LegalProvisionReference`, while the clause id remains the `provisionId`.

### No prose-to-predicate laundering

Legal Interrogation may retain natural-language explanations and propositions, but the concrete compiler bridge refuses to manufacture Legal Effect conditions/exceptions from those strings. A condition or exception must already be a real `LegalPredicate`; otherwise mapping fails closed. This keeps parsing/semantic derivation visible in the interrogation record instead of burying it inside compilation.

### Proposal evidence rule

The bridge does not pre-attach evidence to `LegalNorm`, because Legal Effect v0.14 rejects preattached proposal evidence. Instead `LegalCompileProposal~addEvidenceReference()` receives the verified provision reference; `LegalRuleCompiler` resolves and attaches the compiler-controlled evidence during compilation.

### Qualification

Dev6 is exercised under the exact Library ooRexx 5.3.0 r13196 Internal Test build with the exact Library Intention Service dev11, Legal Effect v0.14, Alchemy Objects v0.8 and Crypto v0.8.3 archives. The live test proves successful compiler certification/publication eligibility and the negative asserted-verification case.
