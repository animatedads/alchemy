# Legal Effect changelog

## v0.14

- Added Alchemy-managed `LegalCounterfactualEvaluator` for explicit deterministic fact sensitivity analysis.
- Added pure `LegalCounterfactualAssumption`, `LegalCounterfactualComparison` and `LegalCounterfactualSet` values.
- Counterfactual evaluation reuses the ordinary `LegalEffectEngine` over the same sealed generation/current context/original action, using explicit `CONTEXT` or `ACTION_OVERRIDE` scope; the trace/query layer does not predict outcomes.
- Counterfactual results are always `hypothetical=true` and `authoritative=false`; assumptions are tagged `COUNTERFACTUAL_ASSUMPTION`; context assumptions appear as predicate fact authority while action overrides also appear as fact mutations.
- Comparison results bind base/alternate `traceIdentity` values and report deterministic status, disposition, controlling-norm, conflict and source-anchor deltas.
- Added `evaluateBoolean()` to actually execute both FALSE and TRUE branches for one fact rather than infer an outcome flip from `reviewInputs()`.
- Added deterministic `counterfactualIdentity` / `setIdentity` and copy-on-read result collections.
- Added a 63-assertion counterfactual regression covering unknown review inputs, action-fact override, authority/conflict sensitivity, explicit UNKNOWN assumptions and failure cases.
- Extended Alchemy integration by 4 assertions for the counterfactual service and its public method contracts.
- Added synthetic `counterfactual_demo.rex`.
- Public legal runtime API remains `legal.effect/0.10`; counterfactuals are analysis artifacts and do not alter legal semantic, compiler, source-authority, runtime or decision-trace authority.

## v0.13

- Added Alchemy-managed `LegalDecisionTraceQuery` as a read-only machine-queryable explanation service over sealed v0.12 decision traces.
- Added copy-on-read `LegalDecisionTraceQueryResult` with deterministic `queryIdentity` bound to the exact source `traceIdentity`.
- Added selectors for final causal closure, controlling norms, suppressed norms, controlling authority rules, fact/applicability changes, source anchors, and review-causing unresolved inputs.
- `reviewInputs()` follows only explicit `REQUIRES_REVIEW` roots into a final `REVIEW_REQUIRED` status; historical/before-state unresolved nodes in a determinate decision are not misreported as blockers.
- Query metadata explicitly records that no counterfactual outcome is inferred and no outcome flip is guaranteed.
- Added a 46-assertion decision-trace query regression and extended Alchemy integration for the query service/contracts.
- Added synthetic `decision_trace_query_demo.rex`.
- Public rule API remains `legal.effect/0.10`; query results are audit projections and do not alter legal semantic, runtime, compiler, source-authority, or decision-trace identity.

## v0.12

- Added `LegalPredicateEvaluation` so norm, modification and authority matches retain the exact structured predicate/fact evaluation used by the engine.
- Added sealed `LegalDecisionTrace`, `LegalDecisionTraceNode` and `LegalDecisionTraceEdge` audit values.
- Added Alchemy-managed `LegalDecisionTraceBuilder`; operational telemetry remains outside legal semantic identity.
- Every successful `LegalEffectEngine~evaluate` now attaches a one-shot structured decision trace while preserving the legacy string trace.
- Trace graph links proposed fact mutations, before/after predicate evaluations, framework modifications, norms, conflicts, authority rules, suppressions, dispositions and final status.
- Added deterministic conflict-node normalisation, sorted trace canonicalisation and `traceIdentity`; equivalent insertion ordering produces the same trace identity.
- Added `whyFinalStatus()` causal-closure traversal.
- Runtime execution envelopes expose the structured trace and include `decisionTraceIdentity` in detached provenance.
- Added 61-assertion structured decision-trace regression and extended Alchemy integration by 3 assertions.
- Added synthetic `decision_trace_demo.rex`.
- Public rule API remains `legal.effect/0.10`; this is an additive explanation/audit surface, not a rule-semantic wire change.

## v0.11

- adopts Alchemy Objects v0.4.3 for Legal Effect operational/service authority objects while deliberately keeping the legal semantic graph lightweight and independent of operational telemetry;
- adds `LegalAlchemyObject` and applies it to framework resolution, legal evaluation, source verification, source-authority trust/verification, compilation and runtime acquisition;
- registers role-specific method contracts and security policies (`AUTHORITY` / `SECURITY_BOUNDARY`, side-effect and authority-effect classifications) for those operational objects;
- exposes bounded operational component identity and disclosure-labelled state through Alchemy introspection without adding Alchemy object IDs, metrics or telemetry to legal semantic identity;
- retains `legal.effect/0.10` as the public legal-rule API because v0.11 changes operational infrastructure rather than legal semantic/wire contracts;
- updates the standalone crypto bridge provider provenance to `oorexx-crypto:*`;
- adds a 37-assertion Alchemy integration regression proving sealed public introspection, live Security Manager semantics, bounded customer disclosure, hidden internal relationships, method telemetry and semantic-identity independence;
- expands deterministic Runtime Registry bundle closure to include `AlchemyEvidence.cls`, `AlchemySecurity.cls`, `AlchemyLockedMethod.cls` and `AlchemyObject.cls`;
- validates the current integration line against Runtime Registry v0.12, Structured Relation v0.9, HardWorld v0.23, Alchemy Objects v0.4.3 and standalone oorexx_crypto v0.1 under ooRexx 5.3.0 r13196.

## v0.10.1

- Makes standalone `oorexx_crypto_v0.1` the explicit SHA-512/Ed25519 dependency; Legal Effect no longer treats Runtime Registry as the source of `crypto.cls`.
- Runtime bundle/evidence tests now include the authoritative crypto source from `CRYPTO_SRC` in immutable closures.
- `LegalEffectBuild~API_VERSION` remains `legal.effect/0.10`; this is a dependency-only patch release.

## v0.10

- advances the live API to `legal.effect/0.10`;
- retains the v0.9 immutable compilation snapshot / TOCTOU repair unchanged;
- adds `LegalSourceAuthorityClaim`, `LegalSourceAuthoritySignature` and immutable multi-signature `LegalSourceAuthorityAttestation`;
- binds authority attestations into compilation input identity and detached compilation-certificate provenance while excluding signer proof from legal semantic identity;
- adds host-owned `LegalSourceAuthorityTrustProfile`, scoped/revocable trusted signers and threshold/required-signer policies;
- rejects duplicate public keys under different signer IDs so one key cannot satisfy a multisignature threshold by aliasing itself;
- adds `LegalSourceAuthorityVerifier`, with host reconstruction of canonical claim text and exact source identity matching before signature verification;
- adds `LegalEd25519SignatureProvider` backed by Runtime Registry v0.11 `crypto.cls`;
- makes `LegalRuntimeRuleResolver` require a host trust profile and host verifier for live legal authority; compiler-certified but unattested sources remain offline-usable and fail closed at live acquisition;
- live acquisition rechecks current signer revocation, source-kind/authority/jurisdiction scope, host policy thresholds and required signer IDs;
- extends `LegalRuntimeSemanticBindingEvidence` / execution envelopes with host source-authority verification evidence;
- adds 30 fast source-authority policy assertions plus a separate 4-assertion real Ed25519 proof;
- updates Runtime Registry fixtures so valid live legal generations carry source-authority attestations and adds a compiled-but-unattested negative fixture;
- validates the current live chain against the user-supplied Runtime Registry v0.11, Structured Relation v0.9 and HardWorld v0.19 clean line under ooRexx 5.3.0 r13196.


## v0.9

- rebased from exact clean-line `legal_effect_v0.7.zip` SHA-256 `32ef8fc0a68f8f9180dcbf3efb6710174fc177bd856e0c70333524013d21742e`;
- advances the live engine API to `legal.effect/0.9`;
- adds immutable `LegalCompilationSnapshot` and a one-way guarded `LegalCompilationUnit~freeze`;
- makes source/provision/proposal and semantic input defensive-copy on ingress and copy-on-read on egress;
- makes snapshot identity, validation and generation construction consume the same frozen object graph;
- builds executable generation objects from fresh snapshot copies, so evidence attachment cannot mutate the certified snapshot;
- freezes failed compilation inputs as well as successful ones; correction requires a new compilation unit;
- rejects subclassed compilation units before any authority-bearing overridden method can execute;
- adds `test_compilation_snapshot_atomicity.rex` covering caller alias mutation, accessor mutation, post-freeze mutation, failed-compile mutation and subclass/re-entrancy attacks;
- updates source-verification acceptance for the consume-on-compile lifecycle;
- execution-validates the complete Legal Effect runtime-evidence chain against Runtime Registry v0.11, Structured Relation v0.9 and HardWorld v0.19 under ooRexx 5.3.0 r13196.

## v0.7

- advances live authority API to `legal.effect/0.7`;
- updates Runtime Registry integration for the sealed `RuntimeGenerationView` authority model while continuing to require detached `RuntimeExecutionEvidence`;
- adds a Structured Relation v0.8 remote Git attestation gate before Legal SHA-512 verification for `GIT_BLOB_CONTENT` / `GIT_SOURCE_SPAN`;
- rejects remote Git states `CLAIMED`, `MISMATCH`, `UNBOUND` and `VERIFICATION_FAILED` with distinct fail-closed diagnostics;
- preserves local Git object-database revisions as valid verification material when no remote claim-bearing state exists;
- restores `cryptographicallyVerified` on source/provision identities as a derived read-only compatibility query backed only by verifier-issued evidence;
- execution-validates the unmodified HardWorld v0.18 v0.5 promotion adapter against the strengthened v0.7 public verifier/compiler surface; compatibility authority remains explicitly `LEGAL_EFFECT/0.5/...`;
- updates deterministic Legal Effect runtime bundling and full runtime-evidence chain to Runtime Registry v0.8 and Structured Relation v0.8;
- preserves source verification, compiler certification, legal semantic identity and runtime execution provenance as separate trust claims.

## v0.6

- advanced live authority API to `legal.effect/0.6`;
- replaced caller-authoritative `VERIFIED` with verifier-issued `LegalSourceVerificationEvidence`; constructor verification labels are retained only as non-authoritative assertions;
- added `LegalVerificationMaterial` preserving the native source object, explicit hashed representation, locator, material and optional parent object;
- added XML document/node, Git file/span and lexical-object verification material adapters without flattening the retained source object into the digest;
- added `LegalSourceVerifier` with injected digest-provider contract and one-shot binding to `LegalSourceIdentity` / `LegalProvisionReference`;
- compiler now rejects missing, failed, identity-inconsistent or parent-inconsistent source/provision verification evidence;
- added `LegalVerificationEvidenceSnapshot` and made compilation certificates retain detached snapshots of the verifier evidence actually relied upon;
- extended `LegalCompilationEvidenceSnapshot` so live runtime evidence retains compiler verification snapshots separately from legal semantic identity and runtime artifact identity;
- added `LegalRuntimeCryptoBridge.cls` providing SHA-512 through Runtime Registry v0.4 `crypto.cls` while keeping core `LegalEffect.cls` digest-provider agnostic;
- strengthened Runtime Registry bundle fixtures to include Legal Effect, the crypto bridge, Runtime Registry crypto and legal rules as one generation-private closure;
- added exact Structured Relation XML source/node verification and public Bitcoin Core #35688 Git blob/span verification;
- added tamper/mismatch, one-shot rebinding, parent-evidence and copy-on-read certificate regression tests;
- execution-validated against Structured Relation v0.7 and Runtime Registry v0.4 under ooRexx 5.3.0 r13196; HardWorld was not mounted and is not claimed as revalidated in this cut.

## v0.5

- merged the v0.4 source-anchored compiler/publication boundary with the Runtime Registry v0.4 execution-evidence chain previously developed on the v0.3 integration line;
- advanced live authority API to `legal.effect/0.5`;
- `LegalFactSet.putRichFact` accepts Runtime Registry evidence envelopes while retaining the original rich fact, native source object and analyser runtime generation evidence;
- added detached `LegalCompilationEvidenceSnapshot` so compiler identity/input identity/certificate metadata remain execution provenance without entering legal semantic identity;
- added `LegalRuntimeSemanticBindingEvidence` linking one compiler-certified legal semantic generation to one exact Runtime Registry execution generation;
- added `LegalEffectExecutionEnvelope` with copy-on-read upstream analyser runtime evidence collected from evidence-bearing facts;
- live `LegalRuntimeRuleLease.evaluate` now captures runtime state at evaluation time, preserving `DRAINING` versus `ACTIVE` across live replacement;
- live `legal.effect/0.5` resolution requires Runtime Registry execution-evidence support and still rejects sealed-but-uncertified legal generations;
- compiler-certified generation remains mandatory: runtime provenance does not replace publication authority, source/provision identity or legal semantic identity;
- added end-to-end Bitcoin Core #35688 evidence-chain acceptance from Structured Relation v0.7 through analyser runtime provenance, Legal Effect compiler certificate, legal runtime provenance and final assessment;
- source/provision `VERIFIED` remains the v0.4 ingestion contract in this cut; runtime evidence does not upgrade or fabricate source verification.

## v0.4

- added `LegalSourceIdentity` and `LegalProvisionReference` for explicit expression/version, locator and content-digest identity;
- source/provision identities are bound into sealed semantic objects and therefore participate in legal semantic identity;
- added `LegalCompileProposal`, `LegalCompilationUnit`, diagnostics/report/certificate objects and `LegalRuleCompiler`;
- compiler accepts `NORM`, `MODIFICATION` and `AUTHORITY_RULE` proposals only when anchored to declared exact provisions;
- compiler validates modification targets, authority winner/loser sources and specifically selected norm IDs;
- rejects missing evidence, undeclared/mismatched evidence identity, pre-sealed proposal payloads and pre-attached proposal evidence;
- LLM/deterministic/human producer identity is retained as provenance and does not itself confer authority;
- successful compilation creates a compiler-certified sealed generation; manual sealing alone is no longer sufficient for Runtime Registry publication;
- added package-private compilation authority token so an ordinary caller cannot self-certify a generation;
- Runtime Registry resolver now fails `LEGAL_GENERATION_NOT_COMPILED` for sealed but uncertified legal modules;
- compiler identity is kept outside legal semantic identity while source/provision content identity remains inside it;
- added compiler-boundary and semantic-kind acceptance tests plus `compiler_boundary_demo.rex`;
- runtime fixtures now build their legal generations through the same compiler gate used by live publication;
- execution-validated against supplied Structured Relation v0.7, Runtime Registry v0.3 and HardWorld v0.14 under ooRexx 5.3.0 r13196.

## v0.3

- added compiler-declared `LegalNorm.conflictKey` for mutually exclusive normative effects;
- added sealed, evidence-bearing `LegalAuthorityRule` with authority source/provision, directional winner/loser selectors, relation type, subject/action scope, temporal scope, jurisdiction, predicates, exceptions and evidence;
- added `LegalNormConflictResult` and assessment surfaces for effective, suppressed, resolved-conflict and unresolved-conflict matches;
- conflicting dispositions are withheld until an applicable authority relation resolves them; absence of authority fails closed as `REVIEW_REQUIRED`;
- explicit private sources cannot supply precedence/choice-of-law authority until bound to the legal context;
- added temporal authority resolution and fail-closed precedence-cycle detection;
- added first-cut conflict-of-laws support through scoped `CHOICE_OF_LAW` authority relations rather than a global governing-law switch;
- preserved the no-universal-rank rule: source kinds do not receive built-in numeric precedence;
- authority rules now participate in sealed semantic canonical identity and copy-on-read generation access;
- Runtime Registry admission API advanced to `legal.effect/0.3` and bridge fixtures now consume `LegalEffectBuild~API_VERSION` rather than hard-coding the previous API;
- execution-validated against supplied Structured Relation v0.7, Runtime Registry v0.3 and HardWorld v0.14 under ooRexx 5.3.0 r13196;
- added authority/conflict and conflict-of-laws tests plus `authority_conflict_demo.rex`;
- recorded Runtime Registry v0.3's stale optional Structured Relation bundle fixture, which omits the new v0.7 `CodeSemanticSource.cls` dependency.

## v0.2

- added `LegalProvision` and resolved `LegalProvisionSnapshot` material state;
- added documentary `LegalModificationEffect` separate from resulting `LegalNorm`;
- supports first-cut `INSERT`, `OMIT`, `SUBSTITUTE`, `MODIFY`, `REPEAL`, `REVOKE`, `COMMENCE`, `EXPIRE`, `SAVE`, `TRANSITION` effects;
- added material-version pinned norms so old/new compiled interpretations can coexist in one sealed generation;
- added `LegalFrameworkResolver` / `LegalFrameworkSnapshot` with modification lineage;
- added deterministic effective-date + explicit-order application and fail-closed `AMBIGUOUS_MODIFICATION_ORDER` detection;
- added scoped unresolved-modification propagation: relevant uncertainty requires review without contaminating unrelated provisions;
- added `LegalJurisdictionGraph` hierarchy resolution;
- private/explicit source binding now applies to modifying instruments as well as norms;
- strengthened rule sealing with copy-on-read semantic collections and detached evidence metadata;
- added synthetic substitution, commencement, repeal+saving, uncertain-effect, private-contract-variation and jurisdiction-hierarchy tests;
- added canonical sealed semantic identity for sources, provisions, documentary effects and norms; insertion order no longer affects semantic identity;
- evidence identity uses explicit canonical identity contracts where available and never relies on arbitrary object `STRING`;
- tightened Runtime Registry authority admission: only `module-kind=LEGAL_RULES` with exact `legal.effect/0.2` API can supply an executable legal generation;
- added optional Runtime Registry v0.3 deterministic bundle integration test;
- Structured Relation import now preserves both the exact native source object and the complete original `RichBusinessFact` envelope across fact-set cloning;
- removed ordinary `result` locals and remaining non-short-circuit boolean expression from Legal Effect-owned ooRexx source;
- added `framework_snapshot_demo.rex`.

## v0.1

- first Legal Effect semantic layer;
- general `NormativeSource` for legislation, regulation, court decisions, contracts, treaties and related sources;
- safe default explicit source binding for contracts/treaties/licences/orders/collective agreements;
- jurisdiction claims by authority + territory + subject matter;
- separate entry-into-force, efficacy and applicability date bounds;
- legal predicates with unknown/conflict propagation;
- sealed rule generations;
- prospective action simulation and newly-applicable/ceased-applicable norm reporting;
- machine-readable prohibited/breach/obligation/status/review dispositions;
- Structured Relation evidence bridge;
- HardWorld assessment projection;
- Runtime Registry leased-generation bridge;
- synthetic three-city food-delivery demonstration.
