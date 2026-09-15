# Legal Effect v0.14

Legal Effect is an ooRexx semantic layer for deterministic, evidence-bearing normative effects.
It is deliberately broader than legislation. A normative source may be legislation, regulation,
a court decision, treaty, contract, licence, administrative order, collective agreement, policy,
or another evidence-backed source of obligations, prohibitions, permissions, rights, powers or status.

The core rule remains:

> **Model-generated is not model-controlled.**



## v0.14 adds deterministic counterfactual / sensitivity evaluation

v0.14 keeps the public legal runtime API at `legal.effect/0.10`. It does not infer alternate outcomes from
`reviewInputs()`. Instead, `LegalCounterfactualEvaluator` explicitly reruns the **same sealed legal generation,
current context and original proposed action** with one explicit hypothetical fact assumption. `CONTEXT` scope (the default) changes a cloned current-world fact before the original action is evaluated; `ACTION_OVERRIDE` scope layers an override after the original action mutations.
The ordinary `LegalEffectEngine` therefore determines the alternate framework, applicability, conflicts,
dispositions and final status.

The new pure value objects are `LegalCounterfactualAssumption`, `LegalCounterfactualComparison` and
`LegalCounterfactualSet`. The evaluator itself is an Alchemy operational service. Counterfactual results are
always labelled `hypothetical=true` and `authoritative=false`; they cannot be mistaken for a live legal lease,
source attestation, rule-generation certificate or evidence that the assumed fact is true.

A comparison binds the exact base and alternate `traceIdentity` values and reports deterministic deltas for:

- final status;
- effective dispositions;
- controlling norm IDs;
- norm-conflict result identities;
- source/provision anchors in the final causal closure.

`evaluateBoolean(assessment, factName)` evaluates both explicit `FALSE` and `TRUE` branches. This is particularly
useful for a `REVIEW_REQUIRED` decision where `reviewInputs()` identifies an unknown boolean fact. The result can
show, for example, that one branch is `ADMISSIBLE` and the other `BLOCKED`, but only because both branches were
actually evaluated by Legal Effect. It never promotes “unknown input” into “guaranteed outcome flip” by inference.

The original assessment/action/context/trace remain unchanged. A `CONTEXT` assumption appears in predicate evaluations with fact authority `COUNTERFACTUAL_ASSUMPTION`; an `ACTION_OVERRIDE` assumption additionally appears as a fact-mutation node. This keeps the hypothetical provenance visible without falsely claiming that a pre-existing world fact was created by the proposed action. Repeating the same assumption against the same base assessment produces
the same deterministic `counterfactualIdentity`; boolean branch sets have a deterministic `setIdentity`.

A new `counterfactual_demo.rex` demonstrates an unknown synthetic licence fact where the `FALSE` branch evaluates
to `ADMISSIBLE` and the `TRUE` branch evaluates to `BLOCKED`.

## v0.13 adds a machine-queryable decision explanation surface

v0.13 keeps the public rule API at `legal.effect/0.10`. It does not alter legal rule semantics,
Runtime Registry admission, source-authority policy, or `LegalDecisionTrace~traceIdentity`. Instead, it adds an
operational query layer over the sealed v0.12 decision graph so downstream systems can consume explanations
without hard-coding node IDs or reparsing narrative trace text.

`LegalDecisionTraceQuery` is an Alchemy-managed read-only service. It returns immutable/copy-on-read
`LegalDecisionTraceQueryResult` values bound to the exact `traceIdentity`. Supported selectors are:

- `whyFinalStatus(trace)` — the complete causal closure for the final status;
- `controllingNorms(trace)` — effective norms that actually produced final dispositions;
- `suppressedNorms(trace)` — norms suppressed by explicit conflict/authority resolution;
- `authorityRules(trace)` — authority rules in the causal path to the final status;
- `whatChanged(trace)` — candidate fact mutations plus applicability-change relations;
- `reviewInputs(trace)` — unresolved predicates/conflicts that causally require review;
- `sourceAnchors(trace)` — source/provision-bearing nodes in the final causal closure.

The query layer is deliberately conservative. `reviewInputs()` does **not** claim that changing an unknown fact
will flip an outcome. It reports what must be resolved before the existing `REVIEW_REQUIRED` decision can become
fully determinate. Actual alternate outcomes require a separate counterfactual evaluation through the rule engine.

Query results have deterministic `queryIdentity` values derived from query type + exact trace identity + selected
nodes/edges/metadata. They are audit projections, not new legal authority, and do not participate in
`LegalRuleGeneration~semanticIdentity` or runtime artifact identity.

A new `decision_trace_query_demo.rex` shows a synthetic statute/contract conflict and extracts the controlling
norm, suppressed contract norm, authority relation, fact mutation and applicability changes as structured objects.

## v0.12 adds deterministic structured decision provenance

v0.12 keeps the public rule API at `legal.effect/0.10`; the legal rule wire/semantic contract is unchanged.
The new surface is an additive audit/explanation graph attached to every successful `LegalEffectAssessment`.
The old string `assessment~trace` remains for compatibility, but downstream systems no longer need to parse prose
to establish why an action was blocked, conditional, admissible, or sent for review.

`LegalPredicateEvaluation` records the exact predicate role, result and fact state/value/authority/evidence used by
`LegalNormMatch`, `LegalModificationMatch` and `LegalAuthorityMatch`. `LegalDecisionTraceBuilder` projects the
completed assessment into sealed, deterministic `LegalDecisionTraceNode` and `LegalDecisionTraceEdge` objects.
The graph relates candidate fact mutations, current/prospective predicate evaluations, framework modifications,
applicable norms, authority/conflict resolution, suppressed norms, effective dispositions and the final status.

The trace is deliberately distinct from legal semantic identity:

```text
LegalRuleGeneration~semanticIdentity   = what the admitted law/rules mean
LegalDecisionTrace~traceIdentity       = why this action/context produced this outcome
Alchemy operational identity           = how the trace builder/service is running
Runtime Registry execution evidence    = which executable generation performed it
```

Trace canonicalisation sorts nodes/edges and normalises conflict-pair identity, so rule insertion order does not
change `traceIdentity` when the admitted semantic generation and decision inputs are equivalent. The graph is
sealed and copy-on-read, and `LegalEffectAssessment~setDecisionTrace` is one-shot. `whyFinalStatus()` walks the
causal graph backwards from the final status and returns the structured causal closure.

The runtime execution envelope exposes the same trace and binds its identity into detached provenance, while the
trace itself retains legal source/provision/evidence anchors rather than flattening them. The trace builder is an
Alchemy operational service; trace nodes/edges remain plain deterministic audit values, so telemetry cannot alter
the explanation or legal semantic identity.

A new synthetic `decision_trace_demo.rex` demonstrates a proposed rate cut becoming applicable, a contract/statute
conflict being resolved by an explicit authority rule, the contract norm being suppressed, and the effective
prohibition causing `BLOCKED`. The demo is synthetic and makes no statement of real law.


## v0.11 adopts Alchemy Objects for operational authority objects

v0.11 keeps the public legal rule API at `legal.effect/0.10`. The semantic graph, sealed legal generation,
source/provision identities, norms, modification effects and authority relations remain ordinary deterministic
Legal Effect value/semantic objects. **Alchemy operational metadata is deliberately excluded from legal semantic
identity.**

The service/controller objects which exercise authority now share the project-wide `AlchemyObject` infrastructure:

- `LegalFrameworkResolver`;
- `LegalEffectEngine`;
- `LegalSourceVerifier`;
- `LegalSourceAuthorityTrustProfile`;
- `LegalSourceAuthorityVerifier`;
- `LegalRuleCompiler`;
- `LegalRuntimeRuleResolver`.

They inherit bounded operational identity, lifecycle/use metrics, method contracts, disclosure-labelled state,
relationship metadata, signed/sealed introspection, instrumentation/telemetry surfaces and live ooRexx Security
Manager semantics from Alchemy Objects v0.4.3. Authority-sensitive methods are registered explicitly as
`AUTHORITY` or `SECURITY_BOUNDARY` operations. Public introspection therefore describes *how the legal service is
operating* without rewriting or leaking the law it carries.

This separation is intentional:

```text
legal semantic identity
    = source/provision/norm/modification/authority semantics

Alchemy operational identity
    = running object identity + contracts + telemetry + security evidence

Runtime Registry identity
    = exact executable generation / closure / execution evidence
```

Changing an Alchemy object ID, touching telemetry, inspecting the compiler, or changing operational metadata does
not change `LegalRuleGeneration~semanticIdentity`. Conversely, legal semantic changes do not silently become
operational configuration changes.

`LegalAlchemyObject` is the local bridge class. It registers package/API identity and the method policies required
by each operational role. The constructor accepts optional Alchemy sealing/capability authorities so hosted
environments can place Legal Effect inside the customer/security-manager boundary without making cryptographic
capability infrastructure mandatory for offline semantic analysis.

Dependencies for the operational line are now explicit:

- Alchemy Objects v0.4.3 (`AlchemyObject.cls` and its local closure);
- standalone `oorexx_crypto_v0.1`;
- ooRexx runtime `json.cls`, required by Alchemy evidence serialization.

The Runtime Registry deterministic bundle test includes the complete local Alchemy source closure, so a Legal
Effect generation does not acquire these facilities from an ambient checkout by accident.


## v0.10 binds live authority to host-owned source attestation

v0.10 is rebased from the accepted v0.9 atomic-compilation cut and validated against the user-supplied clean line from `oorexx-libs(20260822-015258).zip` (outer SHA-256 `9f56ce7a583300075c9548b6701d1253a3a0fbb4864328ae182da10810c49c3f`). The legal/runtime companions used for acceptance are Runtime Registry v0.11 (`0ce20ef4...98323e3`), Structured Relation v0.9 (`37d02bf5...8a4933`) and HardWorld v0.19 (`f879283c...b24294`).

The new boundary separates three claims which must not be conflated:

```text
source representation verification  -> these are exactly the bytes
source authority attestation        -> these bytes are claimed by named signer(s)
legal semantic identity             -> this is the admitted normative graph
```

A `LegalSourceAuthorityClaim` signs the exact source identity metadata: source/expression IDs, canonical URI, content digest, declared authority, jurisdiction, policy ID, issue time and publication reference. One attestation may carry multiple distinct signatures for treaty/contract-style authority. Signatures and signer IDs participate in compilation input/certificate provenance but deliberately do **not** participate in legal semantic identity.

The decisive verification is performed at live acquisition. `LegalRuntimeRuleResolver~acquire(...)` now requires a host-owned `LegalSourceAuthorityTrustProfile` and `LegalSourceAuthorityVerifier`. The legal module cannot supply its own trust roots or weaken the host policy. The host rechecks policy thresholds, required signers, signer scope, duplicate-key protection, revocation and the signature over a host-reconstructed canonical claim. A byte-verified, compiler-certified generation with no source-authority attestation remains valid for offline analysis but is rejected for live authority with `LEGAL_SOURCE_AUTHORITY_ATTESTATION_REQUIRED`.

The runtime binding evidence now retains the successful host verification separately from both the compilation certificate and Runtime Registry execution evidence. Revoking a publisher after compilation therefore prevents a new live lease without rewriting the legal semantic generation.

A production `LegalEd25519SignatureProvider` uses standalone `oorexx_crypto_v0.1`; acceptance includes a fixed Ed25519 signature generated from the RFC 8032 seed/public-key pair and verified by the pure-ooRexx implementation. The larger adversarial policy suite uses a deterministic test provider to avoid turning every regression run into repeated curve arithmetic.

## v0.9 makes compiler input atomic

v0.9 is rebased from the exact user-supplied Legal Effect v0.7 archive
(`32ef8fc0a68f8f9180dcbf3efb6710174fc177bd856e0c70333524013d21742e`) and is
validated on the clean line with Runtime Registry v0.11, Structured Relation v0.9 and
HardWorld v0.19. Runtime Registry v0.11 restores the detached `executionEvidence` /
`RuntimeEvidenceEnvelope` surface required by Legal Effect, so v0.9 changes the Legal
Effect authority boundary rather than compensating for a missing runtime API.

The compiler now consumes one immutable `LegalCompilationSnapshot`. `LegalCompilationUnit`
is mutable only until its first compile/freeze attempt. Sources, provisions, proposals and
semantic payloads are defensively copied on ingress and copy-on-read on egress. The snapshot
identity, validation input, generation construction input and compilation certificate therefore
refer to the same captured object graph. Generation construction works on fresh copies and does
not mutate the snapshot.

A failed compilation also consumes the unit: corrections require a fresh unit and therefore a
fresh compilation-input identity. Subclasses of `LegalCompilationUnit` are rejected at the
compiler authority boundary before an overridden `inputIdentity`, `freeze` or accessor can run.

The exact v0.7 re-entrancy exploit was reproduced before the repair: it inserted a second valid
proposal after the stale input identity had been computed and produced a publication-eligible
generation with two norms while the certificate identity described the pre-mutation unit. v0.9
rejects that same subclass before the attack executes.

```text
v0.7: mutable unit -> identity -> mutation -> validation/build -> stale certificate
v0.9: mutable unit -> freeze -> immutable snapshot -> identity/validation/build/certificate
```

## v0.7 binds remote Git attestation to the source-verification boundary

v0.7 keeps the v0.6 verifier/compiler/runtime evidence model and updates the live boundary for the supplied Structured Relation v0.8 and Runtime Registry v0.8 lines. Runtime publication consumes Runtime Registry's sealed `RuntimeGenerationView` plus detached `RuntimeExecutionEvidence`; Legal Effect does not regain access to the mutable runtime artifact or live generation object.

For Structured Relation v0.8 remote Git objects, Legal SHA-512 representation equality is deliberately **not sufficient** on its own. `GIT_BLOB_CONTENT` and `GIT_SOURCE_SPAN` verification requires the retained remote source object to report successful Git-object attestation (`VERIFIED`, exposed in provenance as `GIT_BLOB_BOUND`) before Legal Effect will bind source/provision verification evidence. `CLAIMED`, `MISMATCH`, `UNBOUND` and verification-failure states fail closed with distinct diagnostics. Local Git object-database revisions without a remote claim state remain valid verification material.

`LegalSourceIdentity~cryptographicallyVerified` and `LegalProvisionReference~cryptographicallyVerified` are restored as **derived read-only compatibility surfaces** for HardWorld v0.18. They return true only when verifier-issued evidence is actually bound and verified; caller-supplied `"VERIFIED"` text still confers no authority. The unmodified HardWorld v0.18 `LegalEffectV05PromotionAdapter` is execution-tested as a compatibility bridge, but its authority namespace remains explicitly `LEGAL_EFFECT/0.5/...`; it is not relabelled as native v0.7 authority.

## v0.6 turns VERIFIED into evidence

v0.6 closes the source-verification gap left deliberately open in v0.5. A caller may still supply a legacy
verification label when constructing `LegalSourceIdentity` or `LegalProvisionReference`, but that label is now
recorded only as `assertedVerificationState`. It does **not** make the identity verified. Publication compilation
requires verifier-issued `LegalSourceVerificationEvidence` bound to the exact source/provision identity.

The verification path is deliberately information-preserving:

```text
retained native source object
        |
        +-- explicit verification representation
        |     XML_SOURCE_TEXT / XML_SOURCE_SPAN
        |     GIT_BLOB_CONTENT / GIT_SOURCE_SPAN
        |     LEXICAL_VALUE / RAW_TEXT
        |
        v
LegalVerificationMaterial
        |
        v
LegalSourceVerifier + digest provider
        |
        v
LegalSourceVerificationEvidence
        |
        +-- expected + calculated digest
        +-- verifier identity
        +-- representation + locator + length
        +-- retained native source object
        +-- optional parent verification evidence
        |
        v
LegalSourceIdentity / LegalProvisionReference
        |
        v
LegalRuleCompiler
        |
        v
LegalCompilationCertificate
        +-- detached LegalVerificationEvidenceSnapshot[]
```

The bytes being hashed are an explicit representation **of** the retained object; they do not replace the object.
For example, XML provision verification retains the exact `XmlNodeRef` while hashing the exact node source span.
Git verification retains the exact `GitFileRevision` or `GitSourceSpan` while hashing the corresponding blob/span
material. Provision verification may carry its parent source-verification evidence, so a provision can be traced
through the source object whose content identity was independently verified.

`LegalSourceVerificationEvidence` can only be created through the package-private verifier authority, and source/
provision verification binding is one-shot. A later caller cannot silently replace the verification evidence beneath
a sealed generation. Compiler certificates therefore snapshot the verification evidence they actually relied upon,
including verifier identity, digest, representation, locator, parent evidence identity and retained source object.

Core `LegalEffect.cls` remains digest-provider agnostic. `LegalRuntimeCryptoBridge.cls` supplies the current SHA-512
provider using standalone `oorexx_crypto_v0.1`; runtime bundles which use that bridge must include that crypto
closure explicitly. This is intentional: source verification, compiler certification, legal semantic identity and
runtime execution provenance remain four separate trust claims.

## v0.5 joins compiler authority to runtime provenance without conflating them

v0.5 retains the complete v0.4 source-anchored compiler boundary and adds the execution-evidence chain from Runtime Registry v0.4. A live result can now retain, independently:

- the original rich Structured Relation / Git / XML / EDI evidence object;
- the analyser Runtime Registry generation which produced an evidence-bearing business fact;
- the compiler-certified legal semantic identity;
- a detached snapshot of the Legal Effect compilation certificate (`compilerId`, compiler version and compiler input identity);
- the Legal Effect Runtime Registry generation which executed the sealed rules; and
- the resulting `LegalAssessment`.

`LegalCompilationEvidenceSnapshot` is deliberately outside legal semantic identity. Two compilers admitting the same source-anchored semantic graph still produce the same legal semantic identity. Likewise, runtime artifact identity does not become legal authority, and runtime provenance does not turn an asserted `VERIFIED` source into a cryptographically verified one.

A `LegalRuntimeRuleLease` refreshes runtime evidence at binding/evaluation time. If generation A is draining after generation B activates, an evaluation through an existing A lease records `DRAINING`; a new B lease records `ACTIVE`. The captured evidence survives lease release without retaining the live Runtime Registry generation object.

`LegalFactSet.putRichFact` accepts a Runtime Registry `RuntimeEvidenceEnvelope`; the Legal Fact keeps the exact native source object, the inner rich fact and the runtime envelope rather than flattening them into a scalar provenance string.

An LLM may discover, draft, structure, explain, challenge or propose a rule. Runtime authority begins only
when the structured objects have been validated and sealed into a `LegalRuleGeneration` and, for live use,
published through the Runtime Registry.

## v0.4 adds the source-anchored compiler boundary

v0.4 separates **proposal** from **publication authority**. A parser, human reviewer or LLM may create a
`LegalCompileProposal`, but that object is not executable law. `LegalRuleCompiler` admits proposals only through
a `LegalCompilationUnit` containing explicit source and provision identities.

The first-cut compiler requires:

- a `LegalSourceIdentity` for every normative source, including expression/version identity, canonical URI,
  content digest, jurisdiction/authority metadata and a verified/unverified state;
- a `LegalProvisionReference` for every provision, including source/expression identity, stable locator,
  provision digest and lexical material;
- an exact primary provision evidence reference for every proposed `LegalNorm`, `LegalModificationEffect` and
  `LegalAuthorityRule`;
- declared modification targets and authority winner/loser sources;
- existence of specifically selected authority winner/loser norm IDs;
- unsealed proposal payloads with no pre-attached evidence, so the compiler owns the promotion from proposal
  evidence reference to executable evidence anchor.

A successful compilation produces a sealed `LegalRuleGeneration` carrying a `LegalCompilationCertificate`.
A manually sealed generation remains useful for offline experiments but is **not publication eligible**.
`LegalRuntimeRuleResolver` rejects it with `LEGAL_GENERATION_NOT_COMPILED`.

The compiler certificate is deliberately outside the legal semantic identity: two independent compilers that
admit the same source-anchored semantic graph produce the same legal semantic identity. Producer identity
(`LLM`, deterministic parser, review tool, etc.) remains evidence provenance rather than becoming authority.

`VERIFIED` source/provision identity is currently an ingestion contract: v0.4 validates and preserves that
state but does not itself compute cryptographic digests from arbitrary source bytes. A later source-verifier
adapter should bind digest calculation/verification evidence directly to Structured Relation/native source
objects before compilation.

## v0.3 adds explicit authority and conflict resolution

v0.3 deals with the case where more than one norm is genuinely applicable and their effects cannot all
stand together. It deliberately does **not** assign numeric rank to source kinds. `LEGISLATION` does not
automatically beat `CONTRACT`, a treaty does not automatically beat a statute, and insertion order is not
legal authority.

A compiler may mark mutually exclusive norms with a shared `conflictKey`. If conflicting dispositions are
applicable, `LegalEffectEngine` withholds both from the effective disposition set until an applicable
`LegalAuthorityRule` resolves the pair. The authority rule itself carries:

- the source and provision which authorise the relation;
- winner and loser source selectors, optionally narrowed to exact norm IDs;
- a relation type such as `PREVAILS_OVER`, `NON_DEROGATION`, `DEROGATES_FROM`, `DISAPPLIES` or
  `CHOICE_OF_LAW`;
- subject matter and action scope;
- temporal scope;
- jurisdiction predicates;
- conditions and exceptions;
- evidence anchors and rationale.

If no applicable authority relation exists, if a potentially controlling relation is unresolved, if two
applicable relations choose different winners, or if the authority graph forms a cycle, the result is
`REVIEW_REQUIRED`. The framework never manufactures precedence from source labels.

The assessment preserves `resolvedConflicts`, `unresolvedConflicts`, `suppressedMatches` and
`effectiveMatches`, so another machine can see not merely the final disposition but exactly what was
suppressed and by which authority relation.

Conflict of laws uses the same explicit mechanism. A contractual governing-law clause can be compiled as a
scoped `CHOICE_OF_LAW` authority relation. Because contracts default to `EXPLICIT` applicability, that relation
has no force until the contract is bound to the transaction. The clause can be scoped to contract
interpretation without silently displacing unrelated mandatory rules.

## v0.2 adds the missing documentary-effect layer

v0.1 represented resulting norms. v0.2 separately represents the legal/documentary operations that change
the material from which those norms arise:

```
INSERT
OMIT
SUBSTITUTE
MODIFY
REPEAL
REVOKE
COMMENCE
EXPIRE
SAVE
TRANSITION
```

A `LegalModificationEffect` identifies:

- the modifying source and provision;
- the target source and provision;
- effect type;
- temporal scope;
- jurisdiction predicates;
- conditions and exceptions;
- explicit application order;
- resulting material version / replacement lexical material;
- evidence anchors.

This is deliberately separate from normative effects such as `OBLIGATION`, `PROHIBITION`, `RIGHT`,
`POWER`, `CONTRACT_TERM` or `STATUS`.

## Framework snapshots

`LegalFrameworkResolver` resolves one sealed generation against one `LegalContext` and produces a
`LegalFrameworkSnapshot`.

The same sealed generation can therefore contain:

```
base provision material
amended material
future material
saved old material
transitional material
```

without pretending that "latest loaded" means "law applicable to this event".

A snapshot is selected by the context, including:

- event time;
- evaluation time;
- jurisdiction;
- subject matter;
- explicit private-source bindings;
- facts relevant to commencement/saving/transitional conditions.

`LegalProvisionSnapshot` retains the applied `LegalModificationEffect` objects as lineage, so the selected
material can be traced back through the modifying instruments.

## Material versions and compiled norms

A `LegalProvision` has an initial material version, for example `BASE`. A substitution can move the
provision snapshot to `AMEND_2026`.

`LegalNorm` can be pinned to a material version:

```
RATE-OLD -> provision 4.1 / material BASE
RATE-NEW -> provision 4.1 / material AMEND_2026
```

At 2026-08-16 the snapshot can enable the first norm. At 2026-08-18 the same sealed generation can enable
the second after a 2026-08-17 substitution. No LLM runs during selection or execution.

A `materialVersion="*"` norm is explicitly version-independent and should be used only when that is intended.

## Commencement, repeal, savings and transition

v0.2 has deterministic first-cut provision states:

```
ACTIVE
NOT_COMMENCED
OMITTED
REPEALED
REVOKED
EXPIRED
SAVED_ACTIVE
TRANSITIONAL_ACTIVE
```

This permits cases such as:

```
REPEAL provision 9.1     order 10
SAVE provision 9.1       order 20 WHEN EXISTING_CASE = true
```

For an existing case, the resolved state can be `SAVED_ACTIVE`; for a new case it remains `REPEALED`.
The rule engine therefore evaluates the appropriate compiled norm instead of flattening saving provisions
into a global on/off date.

These are intentionally first-cut mechanics. v0.2 does not claim that every real saving or transitional
provision can be represented by one status mutation; richer scoped replacement graphs remain future work.

## Jurisdiction hierarchy

v0.2 adds `LegalJurisdictionGraph` so a place can resolve through a hierarchy rather than requiring every
level to be manually repeated in the transaction:

```
SYDNEY
  -> NEW_SOUTH_WALES
      -> AUSTRALIA
```

A norm requiring `NEW_SOUTH_WALES / NEW_SOUTH_WALES / WORK_RELATIONSHIP` can therefore match a context
whose place node is `SYDNEY`.

This does **not** pretend that geographic parenthood alone solves legislative competence or conflict of laws.
Subject-matter-specific jurisdiction claims remain explicit; conflict/choice/precedence is handled separately by the
v0.3 authority-relation layer.

## Private normative sources remain relational

Loading a contract, treaty, licence, administrative order or collective agreement does not make it applicable
to every transaction. Those source kinds default to `EXPLICIT` applicability and require:

```rexx
context~bindSource(sourceId, basis)
```

v0.2 applies the same rule to **modifying instruments**. An unbound private contract variation cannot silently
modify the contract snapshot merely because both documents are loaded in the generation.

## Uncertainty is scoped, not contagious

A modifying effect whose conditions are UNKNOWN/CONFLICT is retained in
`LegalFrameworkSnapshot~unresolvedModifications`.

If that uncertainty can alter a provision containing a norm relevant to the candidate action, the norm is
`UNRESOLVED` and the assessment becomes `REVIEW_REQUIRED`.

An unresolved saving clause for an unrelated provision does not poison an otherwise determinable decision.
This preserves fail-safe behaviour without turning the whole legal corpus into one global uncertainty flag.

## Explicit ordering: never invent legal sequence

Effects are ordered by:

1. effective date;
2. explicit `applicationOrder`.

If two modifying effects share the same target provision, effective date and application order, resolution
fails with:

```
AMBIGUOUS_MODIFICATION_ORDER
```

The engine does not use lexical IDs or insertion order to invent a legally meaningful precedence.

## Structural sealing

v0.2 strengthens v0.1's seal. Rule-bearing collections are copy-on-read and mutation methods reject changes
after sealing. Tests cover:

- source evidence;
- provision evidence;
- norm conditions/evidence;
- modification conditions/evidence;
- generation norm/modification collections;
- evidence metadata copies.

This prevents a caller from obtaining an internal rule array and mutating a supposedly sealed generation by
reference.

## Prospective action evaluation

`LegalEffectEngine` still evaluates:

```
current world
current world + candidate action
```

but v0.2 resolves a legal framework snapshot for each. A proposed operational action can therefore alter facts
which change normative applicability, while documentary modification effects independently select the legal
material applicable at the transaction's time and place.

The result remains machine-readable:

```
ADMISSIBLE
CONDITIONAL
REVIEW_REQUIRED
BLOCKED
```

with dispositions such as:

```
PROHIBITED
CONTRACT_BREACH
TREATY_BREACH
REQUIRES_OBLIGATION
STATUS_EFFECT
REVIEW
```

## Identity is deliberately split three ways

Legal Effect does not treat a runtime package hash as the identity of the law, and it does not treat a legal
snapshot as the identity of either the code or the rule corpus. v0.2 keeps three concepts separate:

```
legal semantic identity
    exact sealed source/provision/modification/norm/authority graph

runtime artifact identity
    exact bundled ooRexx/code closure published by Runtime Registry

legal framework snapshot identity
    sealed semantic generation + jurisdiction/time/context/source bindings
```

The separation matters. The same engine bytes can carry different legal material, and the same legal material
can be packaged by a different engine build. A future signed production bundle should cryptographically bind
these identities rather than collapse them into one opaque identifier.

`LegalRuleGeneration~semanticIdentity` is currently a version-framed canonical serialization of the sealed
semantic graph. Canonical collection ordering means construction/insertion order is not authority. A semantic
change to a norm or declared evidence identity changes the canonical identity. Arbitrary evidence objects are
never implicitly stringified to obtain identity.

## Companion integration

v0.14 is execution-validated against the current consolidated roll-up:

- Runtime Registry v0.12;
- Structured Relation Plugin v0.9;
- Virtual RYTA / HardWorld v0.23;
- Alchemy Objects v0.4.3;
- standalone oorexx_crypto v0.1;
- Open Object Rexx 5.3.0 r13196.

Structured Relation supplies the rich XML/Git objects used by the verifier tests. The XML verification probe hashes
exact document/node source material while retaining the `XmlDocumentContext` / `XmlNodeRef`; the Git probe retains
the exact source/blob identity and representation evidence.

Runtime Registry supplies immutable executable generations, deterministic bundle closure and detached runtime
execution evidence. The shipped Legal Effect runtime bundle now contains `LegalEffect.cls`,
`LegalRuntimeCryptoBridge.cls`, standalone `crypto.cls`, the Alchemy Object four-file source closure and the rule
fixture; all local `::REQUIRES` links are closure-bound before staging. Runtime admission requires
`module-kind=LEGAL_RULES` and API `legal.effect/0.10`.

The full evidence-chain test retains source verification, issuer-attestation verification, Structured Relation
analyser runtime evidence, compiler snapshots, legal semantic identity, Alchemy operational identity and Runtime
Registry execution evidence as distinct traversable objects. HardWorld consumes the resulting legal assessment and
its promotion evidence without becoming the owner of legal semantics.

## Examples

`examples/food_delivery_demo.rex` demonstrates synthetic Los Angeles/Sydney/London operational constraints.

`examples/framework_snapshot_demo.rex` demonstrates a synthetic Sydney hierarchy and a change on 2026-08-17:

```
Sydney 2026-08-16: material=BASE       result=ADMISSIBLE
Sydney 2026-08-18: material=ORDER_2026 result=CONDITIONAL
```

It also demonstrates that a loaded contract remains inert until explicitly bound to the transaction.

`examples/authority_conflict_demo.rex` demonstrates fail-closed conflicting norms and an explicit evidence-bearing authority relation.

`examples/compiler_boundary_demo.rex` demonstrates an LLM-labelled proposal succeeding only when anchored to an exact verified provision, then shows the same model proposal shape being rejected when the source anchor is absent.

`examples/decision_trace_demo.rex` demonstrates the sealed causal graph behind a synthetic blocked rate change.

`examples/decision_trace_query_demo.rex` demonstrates machine selectors over that graph: controlling norm, suppressed norm, controlling authority relation, fact mutation and applicability changes.

`examples/counterfactual_demo.rex` actually evaluates both boolean branches of one unresolved synthetic licence fact and compares the resulting statuses and controlling norms.

All city/clause/rule material in the examples is synthetic test data. It is not asserted to be current law.

## Run

```bash
export REXX=/path/to/oorexx/usr/local/bin/rexx
export LD_LIBRARY_PATH=/path/to/oorexx/usr/local/lib
export REXX_PATH=/path/to/oorexx/usr/local/bin
export ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.4.3
export CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src
export STRUCTURED_RELATION_ROOT=/path/to/structured_relation_plugin_v0.9
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.12
export HARDWORLD_ROOT=/path/to/virtual_ryta_hardworld_v0.23
./run_tests.sh
```

`json.cls` is supplied by the ooRexx runtime and must be visible on `REXX_PATH`; Alchemy evidence serialization
uses it. Standalone `oorexx_crypto_v0.1` and Alchemy Objects v0.4.3 are explicit external package dependencies.
Runtime Registry, Structured Relation and HardWorld remain integration companions rather than sources of the Legal
Effect semantic API.

## Deliberate current boundaries

- `LegalRuleCompiler` validates structured proposals; it does not parse arbitrary statutes, contracts or treaties itself.
- source/provision digest verification proves equality to one explicit retained representation; source-authority attestation separately establishes a trusted issuer claim, but authoritative *retrieval* and publisher certificate-chain policy remain an upstream concern.
- XML/Git verification adapters are evidence bridges, not universal canonicalisation rules. Different authoritative formats may require explicitly versioned representation/canonicalisation policies.
- `conflictKey` remains compiler-declared semantic structure; Legal Effect does not infer every possible legal conflict from arbitrary prose or disposition names.
- `LegalAuthorityRule` remains an explicit directional authority relation. Real importers must derive it from authoritative doctrine, provisions, judgments, treaty rules or binding private instruments.
- contradictory controlling authority relations still fail closed; there is no magic universal statute/treaty/contract rank.
- there is not yet a native legal XML/contract/treaty adapter that constructs the complete proposal graph directly from Structured Relation material.
- there is no NoSQL/Algorithm Relation projection yet for compiler proposals, authority relations, source-attestation lineage and framework snapshots.
- substituted lexical text does not automatically regenerate normative rules; re-compilation remains an explicit compiler/import task.
- `SAVE` / `TRANSITION` remain first-cut scoped provision-state mechanics, not a complete model of every legal drafting pattern.
- Alchemy operational telemetry and introspection are explicitly *not* legal semantic evidence unless a separate legal rule names them as factual input.
- `reviewInputs()` still identifies unresolved causal inputs without predicting an outcome. `LegalCounterfactualEvaluator` supplies the separate deterministic fact-only sensitivity path; time, jurisdiction, source bindings and arbitrary structural changes remain outside this first counterfactual cut.
- no LLM interface exists inside executable authority. LLM participation ends at proposal production.
- the synthetic demos are architecture tests, not statements of current law or legal advice.

## Shared crypto dependency

Legal Effect remains digest-provider neutral at the core. SHA-512/Ed25519 authority verification is supplied by
standalone `oorexx_crypto_v0.1`; Runtime Registry no longer acts as a transitive crypto source. Deterministic runtime
bundles include the authoritative crypto and Alchemy source closure as immutable generation units.
