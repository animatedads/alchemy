# Legal Effect v0.11 architecture

## Core invariant

**Model-generated is not model-controlled.**

A model can propose structured legal material. Executable authority is a separately validated and sealed
rule generation. Runtime evaluation never asks an LLM to reinterpret a clause.


## Semantic law versus operational object infrastructure (v0.11)

Legal Effect now uses Alchemy Objects v0.4.3 at the **operational authority boundary**, not as the representation
of law itself. This is a deliberate two-domain design.

```text
sealed legal semantic graph                       operational authority objects
---------------------------                       -----------------------------
LegalSourceIdentity                               LegalSourceVerifier
LegalProvisionReference                           LegalSourceAuthorityTrustProfile
LegalNorm                                          LegalSourceAuthorityVerifier
LegalModificationEffect                           LegalFrameworkResolver
LegalAuthorityRule                                LegalEffectEngine
LegalRuleGeneration                               LegalRuleCompiler
                                                   LegalRuntimeRuleResolver
          |                                                   |
          | semanticIdentity                                  | AlchemyObject
          v                                                   v
 deterministic legal meaning                         identity / contracts / telemetry
                                                     introspection / capability / security
```

The right-hand objects subclass `LegalAlchemyObject`, which in turn subclasses `AlchemyObject`. They receive the
shared project infrastructure for bounded identity, state disclosure, method contracts, instrumentation, sealed
introspection, Security Manager semantics, capabilities, relationships and telemetry.

The left-hand objects remain lightweight Legal Effect semantic/value objects. Alchemy object identity, counters,
telemetry, introspection evidence and capability state are **not inputs to legal semantic canonicalisation**. This
prevents an operational restart, a telemetry counter increment or an inspection request from changing what the law
means. A regression test explicitly touches compiler telemetry and proves the sealed generation semantic identity
is unchanged.

Operational method policy is explicit. In v0.11, compilation and framework/evaluation operations are registered as
authority use; source verification, source-authority verification and runtime acquisition are security boundaries;
trust-profile mutation is an authority-granting mutation. These declarations are introspectable and can therefore be
cryptolocked/capability-gated by a hosted Alchemy Security Manager without modifying the deterministic legal graph.

The deterministic Runtime Registry bundle owns the required Alchemy source closure. Cross-package code must depend
on the public Alchemy/Legal Effect contracts, not accidental class-object identity from another package namespace.


## Host-owned source-authority boundary (v0.10)

```text
retained native source bytes
        |
        v
LegalSourceVerificationEvidence
        |
        +---- exact LegalSourceIdentity
        |
        v
LegalSourceAuthorityClaim
        +---- policyId
        +---- authority / jurisdiction
        +---- source/expression/URI/digest
        +---- publication reference / issue time
        |
        v
LegalSourceAuthorityAttestation
        +---- one or more signer/signature proofs
        |
        v
immutable LegalCompilationSnapshot
        |
        v
compiler certificate + sealed legal generation
        |
        v
Runtime Registry lease
        |
        +---- HOST trust profile
        +---- HOST signature verifier
        +---- current revocation/scoping/policy state
        |
        v
LegalSourceAuthorityVerificationEvidence
        |
        v
LegalRuntimeSemanticBindingEvidence
```

The rule module carries claims and proof material; it does not carry live trust authority. The resolver requires host-owned trust/profile objects and re-verifies every normative source before returning a live lease. This is deliberately later than compiler admission so a source can remain usable for offline modelling even where no production publisher trust has been configured.

The host reconstructs the canonical claim from data fields before signature verification; it does not trust a bundled module implementation of `canonicalText` or `matchesIdentity`. Cross-package objects are admitted by exact public class IDs because a Runtime Registry bundle creates package-private class objects distinct from the host's class objects. Host trust-profile and verifier classes remain exact host package objects.

Signer proof is provenance rather than semantics: changing trusted signing key/proof path changes compilation input/certificate evidence but leaves the sealed legal semantic identity unchanged when source identity and normative graph are otherwise identical.

## Atomic compilation-input authority boundary (v0.9)

Compilation is a one-way transition from a mutable authoring object to a frozen input snapshot:

```text
LegalCompilationUnit (mutable)
        |
        | freeze() -- guarded, one way
        v
LegalCompilationSnapshot (immutable semantic capture)
        |
        +-- inputIdentity
        +-- source/provision validation
        +-- proposal validation
        +-- fresh generation work copies
        +-- LegalCompilationCertificate
```

`identity input == validation input == generation input` is an authority invariant. The compiler
never asks the mutable unit for semantic material after freezing it. The snapshot itself is not a
generation workspace: compiler evidence anchors are attached to fresh semantic copies so successful
compilation does not change the snapshot identity.

The compiler accepts only the exact public `LegalCompilationUnit` class at this boundary. That is
deliberately stricter than ordinary ooRexx polymorphism: a subclass could otherwise override
`inputIdentity`, `freeze`, or semantic accessors and reintroduce re-entrancy between certification
and construction.

Any compile attempt consumes/freeze the input even when validation fails. A corrected legal proposal
is a new compilation input and must be represented by a new unit and a new input identity.

## Verification, compilation, semantics and execution are separate trust claims

v0.7 carries four independently meaningful evidence domains through live evaluation:

```text
retained source object
    -> LegalSourceVerificationEvidence
    -> source/provision identity
    -> compiler-certified LegalRuleGeneration
    -> LegalCompilationCertificate + verification snapshots
    -> LegalRuleGeneration semantic identity
    -> Legal Effect RuntimeExecutionEvidence
    -> LegalEffectExecutionEnvelope
```

Upstream analysis may additionally contribute its own Runtime Registry evidence through a `RuntimeEvidenceEnvelope`.
These domains do not substitute for one another:

- **source verification evidence** says which explicit representation was hashed and whether it matched an expected digest;
- **compiler certification** says which verified compilation inputs were admitted into an executable rule generation;
- **legal semantic identity** identifies the canonical sealed normative/documentary/authority graph;
- **runtime execution evidence** identifies the immutable code generation and dependency closure which executed it.

The expected digest and verifier/provider trust are themselves separate provenance questions. A successful digest match
does not prove that the expected digest was obtained from an authoritative publication channel. v0.7 therefore does
not promote digest machinery into legal authority.

Runtime Registry state is sampled at binding/evaluation time so old leases correctly record `DRAINING` after
replacement. Captured provenance is detached from live generation objects so audit evidence does not pin retired code.


### v0.7 remote-source and runtime authority refinement

Runtime Registry's public generation surface is now a sealed `RuntimeGenerationView`; Legal Effect resolves live rules through that view and separately requires detached `RuntimeExecutionEvidence`. For remote Structured Relation v0.8 Git objects, source-byte SHA-512 verification is gated by the source object's own Git-object attestation state. This keeps Git identity attestation, Legal representation verification, compiler certification and runtime execution provenance as distinct claims.

The `cryptographicallyVerified` methods exposed on source/provision identities are compatibility queries derived from bound verifier evidence. They are not setters and do not restore caller-authoritative verification labels.

## Four distinct semantic layers

```
1. evidence/material
   NormativeSource
     -> LegalEvidenceAnchor[]
     -> LegalProvision[]

2. documentary/legal modification effect
   LegalModificationEffect
     -> INSERT / OMIT / SUBSTITUTE / MODIFY
     -> REPEAL / REVOKE / COMMENCE / EXPIRE
     -> SAVE / TRANSITION

3. normative effect
   LegalNorm
     -> OBLIGATION / PROHIBITION / PERMISSION
     -> RIGHT / POWER / STATUS / CONTRACT_TERM / ...

4. authority / conflict relation
   LegalAuthorityRule
     -> PREVAILS_OVER / NON_DEROGATION / DEROGATES_FROM
     -> DISAPPLIES / CHOICE_OF_LAW / other compiled directional relations
```

Do not collapse layers 2, 3 and 4. "Section 4 is substituted", "the resulting section prohibits X", and
"that prohibition prevails over clause 7 for this subject matter" are different facts with different provenance.
A source kind is not itself an authority relation.

## Source verification and compiler / publication trust boundary

The executable path is now:

```text
authoritative/native source material
        |
        +--> LegalVerificationMaterial
        |      explicit representation + retained object + locator
        |
        v
LegalSourceVerifier
        |
        +--> LegalSourceVerificationEvidence
        |      expected/actual digest, verifier, representation, parent evidence
        |
        v
LegalSourceIdentity + LegalProvisionReference
        |
        +--> parser / reviewer / LLM proposals
        |       LegalCompileProposal
        |
        v
LegalCompilationUnit
        |
        v
LegalRuleCompiler
  -> requires verifier-issued source/provision evidence
  -> checks digest and identity consistency
  -> checks provision-to-source verification parentage
  -> exact primary provision anchoring
  -> target/selector existence checks
  -> rejects pre-sealed or pre-evidenced proposal payloads
        |
        v
LegalCompilationCertificate
  -> detached LegalVerificationEvidenceSnapshot[]
        +
sealed LegalRuleGeneration
        |
        v
publicationEligible = true
```

Caller-provided `VERIFIED` is retained only as `assertedVerificationState`; it has no authority. Actual verification
state is derived from verifier evidence and may be bound only once. The compiler will reject identities with missing,
failed or inconsistent verification evidence.

The material hashed by the verifier is an explicit representation of a retained source object. `XML_SOURCE_SPAN` and
`GIT_SOURCE_SPAN`, for example, retain the native node/span object in the evidence while hashing its exact source
material. A provision verification may link to its parent source verification, allowing the compiler certificate to
preserve both levels of provenance.

A plain `LegalRuleGeneration~seal` provides immutability but not publication authority. The compiler uses a
package-private compilation authority token when attaching a certificate, so ordinary callers cannot self-certify.
Compiler certificates carry detached verification snapshots, but neither compiler identity nor verifier identity is
folded into `LegalRuleGeneration~semanticIdentity`: those are provenance/trust claims about how the semantic graph
was admitted, not the meaning of the graph itself.

Core Legal Effect is digest-provider agnostic. The shipped `LegalRuntimeCryptoBridge.cls` supplies SHA-512 from
standalone `oorexx_crypto` `crypto.cls`; a live generation using it must include that dependency in its immutable closure.

## Resolution path

```
sealed LegalRuleGeneration
        +
LegalContext(eventTime, evaluationTime, jurisdiction, facts, source bindings)
        |
        v
LegalFrameworkResolver
        |
        v
LegalFrameworkSnapshot
  -> LegalProvisionSnapshot{}
       status
       materialVersion
       lexicalText
       modification lineage[]
  -> appliedModifications[]
  -> unresolvedModifications[]
        |
        v
LegalEffectEngine
  -> selects norms enabled by provision status/material version
  -> applies source binding / jurisdiction / temporal / predicate rules
  -> groups compiler-declared mutually exclusive norms by conflictKey
  -> resolves conflicts only through applicable LegalAuthorityRule objects
  -> withholds unresolved conflicting dispositions
  -> compares current vs candidate-action world
        |
        v
LegalEffectAssessment
  -> effectiveMatches[]
  -> suppressedMatches[]
  -> resolvedConflicts[]
  -> unresolvedConflicts[]
```


## Identity and provenance boundaries

There are multiple identities/evidence objects and none may silently stand in for another:

```text
source verification evidence
    = digest comparison over one explicit representation of one retained source object

LegalRuleGeneration semantic identity
    = canonical sealed normative/documentary/authority graph

LegalCompilationCertificate
    = compiler/input admission provenance + verifier-evidence snapshots

RuntimeArtifact / RuntimeBundle identity
    = exact executable ooRexx/code closure

LegalFrameworkSnapshot
    = one semantic generation resolved through event time, jurisdiction, facts and source bindings
```

Canonical semantic identity is defined only after sealing. Collections are canonicalised independently of insertion
order. Evidence participates through explicit identity contracts; arbitrary display `STRING` representations are not
treated as legal evidence identity. A future signature/attestation layer should bind these identities while retaining
their distinctions, not collapse them into one opaque hash.

## Time is not registry activation time

Runtime Registry answers: "which immutable implementation generation did this request acquire?"

Legal Framework resolution answers: "inside that generation, which legal material governs this event?"

An in-flight request can remain pinned to Runtime Registry generation G1 while that generation itself resolves:

```
2026-08-16 event -> BASE material
2026-08-18 event -> AMEND_2026 material
```

A later Runtime Registry activation does not retroactively redefine the first transaction.

## Material-version selection

A provision carries an initial material version. Documentary effects can alter the resolved version. Norms
may be compiled for a specific material version. This permits old and new interpretations to coexist in one
sealed generation while only the legally applicable one executes.

The relation is explicit:

```
LegalNorm.sourceId + LegalNorm.provisionId + LegalNorm.materialVersion
                        |
                        v
LegalProvisionSnapshot
```

## Saving/transitional mechanics

Modification effects are applied deterministically in effective-date / explicit-order sequence. A saving or
transitional effect can re-enable old material for a qualifying context after a general repeal/replacement.
Its conditions are evaluated against the same evidence-bearing `LegalFactSet` used by the legal context.

Unknown/conflicting applicability is retained as unresolved evidence; it is not guessed.

## Jurisdiction

`LegalJurisdictionClaim` remains authority + territory + subject matter + basis.

`LegalJurisdictionGraph` adds geographic/authority ancestry for common cases such as city -> state -> country.
The graph is a convenience for derived geographic applicability. It is not itself a conflict-of-laws engine.
Competence, choice of law, mandatory rules, treaty effect and precedence are represented explicitly through
normative and authority relations rather than inferred from geographic ancestry.

## Authority, precedence and conflict of laws

`LegalNorm.conflictKey` is an explicit compiler assertion that multiple otherwise-applicable norms participate
in one mutually exclusive legal effect question. The engine does not infer a conflict merely because two
sources have different kinds or produce different prose.

`LegalAuthorityRule` is itself part of the sealed semantic generation. It identifies its own authority source
and provision, directional winner/loser selectors, relation type, subject/action scope, temporal scope,
jurisdiction, predicates, exceptions and evidence. Thus precedence is data with provenance, not framework code.

Resolution is fail-closed:

```
conflicting applicable norms
      |
      +-- no authority relation --------------------> REVIEW_REQUIRED
      +-- authority condition unknown/conflicting --> REVIEW_REQUIRED
      +-- two controlling rules choose differently -> REVIEW_REQUIRED
      +-- precedence cycle --------------------------> REVIEW_REQUIRED
      +-- one determinate authority relation --------> winner effective / loser suppressed
```

Conflict of laws is represented by the same mechanism rather than a special global `governingLaw` switch.
For example, a bound contract clause may supply a scoped `CHOICE_OF_LAW` rule selecting English contract law
for interpretation. That does not by itself say anything about a different action governed by a mandatory NSW,
California or UK rule. Any non-derogation or mandatory-law effect must itself be represented by an authority
relation with its own evidence and scope.

The framework intentionally has no universal hierarchy such as `STATUTE=100`, `TREATY=90`, `CONTRACT=20`.
Those numbers would incorrectly encode jurisdiction-specific doctrine as engine policy.

## Private-source binding

`CONTRACT`, `TREATY`, `LICENCE`, `ADMINISTRATIVE_ORDER` and `COLLECTIVE_AGREEMENT` default to `EXPLICIT`.
The source must be related to the legal context before its norms or its modifying effects are eligible.

This prevents corpus membership from being mistaken for transaction applicability.

## Ordering safety

A legal engine must not invent precedence from file order or an effect identifier. Therefore two effects with
identical target + effective date + application order produce `AMBIGUOUS_MODIFICATION_ORDER`.

Real importers must provide an order derived from authoritative amendment metadata or surface the ambiguity
for review.

## Sealing

Sealing is both behavioural and structural:

- mutation methods fail after seal;
- rule-bearing arrays/tables are returned as copies;
- generation collections are returned as copies;
- evidence metadata is copied on read.

The Runtime Registry still owns live publication and generation leasing. Legal Effect additionally requires a
runtime generation to advertise `module-kind=LEGAL_RULES` and the exact `legal.effect/0.10` artifact API before
its module can supply executable legal authority. A method name alone is not an authority boundary.

Runtime Registry v0.12 bundles the Legal Effect/rule/crypto/Alchemy closure into one deterministic generation-private
source artifact. The shipped integration test exercises this path with `LegalEffect.cls`, `LegalRuntimeCryptoBridge.cls`,
standalone `oorexx_crypto` `crypto.cls`, the four-file Alchemy Object closure and a compiler-built rule fixture. Source
authority signatures, compiler identity, legal semantic identity and Runtime Registry execution evidence remain separate
auditable identities rather than interchangeable proofs.

## Relation to Structured Relation

Structured Relation owns rich source objects and their evidence API. Legal Effect may verify an explicit source
representation while retaining the native object itself. v0.6 ships adapters for:

- `XmlDocumentContext` -> `XML_SOURCE_TEXT`;
- `XmlNodeRef` -> exact `XML_SOURCE_SPAN`;
- `GitFileRevision` -> `GIT_BLOB_CONTENT`;
- `GitSourceSpan` -> `GIT_SOURCE_SPAN`;
- generic lexical objects -> `LEXICAL_VALUE`.

Projection into SQL/relation rows remains separate from verification and authority. For imported `RichBusinessFact`
material, `LegalFact.source` retains the exact native source object while `LegalFact.evidence` retains the complete
rich-fact/runtime envelope. Verification evidence can point to the same object without flattening it into a digest.

## Relation to HardWorld

HardWorld remains domain-neutral. `LegalHardWorldBridge` projects determinate assessment facts such as:

```
LEGAL_ACTION_BLOCKED
LEGAL_ACTION_REVIEW_REQUIRED
LEGAL_ACTION_CONDITIONAL
```

and keeps the complete `LegalEffectAssessment` as the fact source.

## Next structural work

The next useful families are:

1. **authoritative retrieval / publisher chain** — bind fetched bytes to publisher/channel/certificate evidence before Legal Effect source verification and source-authority policy consume them;
2. **native legal-source adapters** — derive complete source/provision/proposal graphs from authoritative XML, contracts and treaty material while retaining exact Structured Relation evidence objects;
3. **versioned representation/canonicalisation policy** — explicit canonical byte rules for formats where raw source spans are not the authoritative digest representation;
4. **NoSQL/Algorithm Relation projection** — queryable legal effects, compiler proposals, authority attestations and framework lineage without losing rich evidence identity;
5. **Alchemy-hosted authority controls** — use capability/cryptolocked method infrastructure for deployments that require customer-visible but bounded inspection and explicit grants around compile/verify/acquire operations;
6. **reducer/decision formalisation** — continue shrinking any remaining implementation-order effects so semantic identity and executable disposition are demonstrably order-independent wherever the rule model says they should be.

## v0.13 machine-queryable explanation projection

The sealed decision trace is now treated as a stable audit graph which can be queried without re-running the legal
engine. `LegalDecisionTraceQuery` is an operational Alchemy service; `LegalDecisionTraceQueryResult` is a plain
deterministic projection value. The query boundary is intentionally downstream of decision formation:

```text
LegalEffectEngine
    -> completed LegalEffectAssessment
    -> sealed LegalDecisionTrace
          |
          +-> LegalDecisionTraceQuery~controllingNorms
          +-> ~suppressedNorms
          +-> ~authorityRules
          +-> ~whatChanged
          +-> ~reviewInputs
          +-> ~sourceAnchors
```

A query never changes applicability, precedence, dispositions, final status, legal semantic identity or
`traceIdentity`. It selects existing nodes/edges from one sealed trace and binds that projection to the originating
trace identity. The result therefore has its own deterministic `queryIdentity` while remaining non-authoritative.

`reviewInputs()` is deliberately narrower than counterfactual reasoning. It starts from explicit
`REQUIRES_REVIEW` edges into the final status and walks only their causal roots, returning unresolved norm/conflict
nodes and `UNKNOWN` predicate evaluations. A historical unresolved predicate which became known because the
candidate action supplied a fact is not a review blocker when the final decision is determinate.

This leaves counterfactual/sensitivity analysis as a distinct future operation: alternate facts must be fed back
through the same deterministic engine and compared as separate assessments rather than guessed from the trace.

## v0.12 structured decision provenance

A legal result is now accompanied by a deterministic causal graph rather than only a presentation trace.
The graph is a projection of the already-completed assessment; it does not decide applicability or precedence
and therefore cannot become a second rule engine.

```text
candidate LegalAction
   |
   +-- FACT_MUTATION ----------------------+
   |                                       |
current/prospective facts                  v
   |                               PREDICATE_EVALUATION
   |                                       |
framework snapshot / modification --------+--> NORM
                                               |
                             AUTHORITY_RULE --> NORM_CONFLICT
                                               |       |
                                               |       +--> suppressed norm
                                               v
                                         effective norm
                                               |
                                               v
                                          DISPOSITION
                                               |
                                               v
                                             STATUS
```

`LegalPredicateEvaluation` is produced by the same `evaluate()` call which determines each norm,
modification or authority-match status, so the trace builder does not re-run or reinterpret predicates.
It consumes exact match objects and evidence already produced by Legal Effect.

`LegalDecisionTraceBuilder` is an operational Alchemy object because building/exporting audit material is a
service activity. `LegalDecisionTrace`, nodes, edges and predicate evaluations are plain value objects. Neither
Alchemy object IDs nor telemetry participate in trace or legal semantic identity.

Trace edges point from cause toward effect. `whyFinalStatus()` follows incoming edges backwards from the final
status node, yielding a structured causal closure suitable for HardWorld, Shannon, optimisers, auditors or an LLM
explanation layer. Those consumers can render prose if desired without becoming the source of the legal result.

Runtime execution envelopes expose the exact assessment trace and add its `traceIdentity` to detached provenance.
The runtime artifact identity, legal semantic identity, compiler/source authority evidence and decision-trace
identity remain separate claims.


## v0.14 deterministic counterfactual / sensitivity evaluation

v0.13 deliberately stopped at identifying unresolved review inputs. v0.14 adds the separate operation required to
answer an actual “what if?” question without turning the explanation graph into a second rule engine.

```text
completed LegalEffectAssessment
      |
      +-- base sealed decision trace
      |
      +-- original LegalAction --------------------+
      |                                             |
      +-- same sealed LegalRuleGeneration           |
      +-- same current LegalContext                  |
                                                    v
                               explicit counterfactual assumption
                                                    |
                                                    v
                                        copied action + override
                                                    |
                                                    v
                                         LegalEffectEngine~evaluate
                                                    |
                                                    v
                                      alternate sealed decision trace
                                                    |
                                                    v
                                   LegalCounterfactualComparison
```

Counterfactual assumptions have an explicit scope. `CONTEXT` (the default) mutates a clone of the current fact set before the original action is evaluated, which is correct for pre-existing but unresolved facts such as licence status. `ACTION_OVERRIDE` instead appends the assumption after the copied original action mutations, which is correct for sensitivity over a fact created by the proposal itself. The original context and action remain unchanged. In both scopes the alternate engine run is a genuine Legal Effect evaluation: jurisdiction, temporal material versions, modification effects, norm applicability, authority rules and conflicts are all recalculated.

Counterfactual analysis is intentionally non-authoritative. The result carries `hypothetical=true` and
`authoritative=false`, and the assumed fact is marked `COUNTERFACTUAL_ASSUMPTION` in the alternate decision trace. Context assumptions are visible through predicate fact authority rather than being misrepresented as action-caused mutations; action overrides are explicit mutation nodes.
No counterfactual result can substitute for source evidence or a Runtime Registry legal lease.

`LegalCounterfactualComparison` compares the two actual traces rather than narrating a guessed difference. It records
status/disposition changes, controlling norms, conflict result identities and source/provision closure changes. Its
identity binds both trace identities plus the exact assumption and delta projection.

For boolean review inputs, `evaluateBoolean()` runs both branches explicitly. This means a caller may say:

```text
LICENCE_ACTIVE = FALSE -> ADMISSIBLE
LICENCE_ACTIVE = TRUE  -> BLOCKED
```

only after both branches have passed through the deterministic engine. It may not derive either branch merely from
the presence of an `UNKNOWN` predicate in the explanation graph.
