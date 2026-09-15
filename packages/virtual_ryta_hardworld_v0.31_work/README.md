# Virtual RYTA / HardWorld v0.31-work database promotion-basis boundary / current API roll-up

## v0.31-work: database provenance may be basis, never authority

`DatabaseTransactionPromotionBasisAdapter` permits v0.30 detached transaction/retry evidence to be cited as an `EvidencePromotionBasis` by a separately-authorized promotion. The basis id is the deterministic database evidence identity; the native detached evidence remains reachable for audit.

```text
database transaction evidence -> promotion basis        allowed
database transaction evidence -> direct promotion      refused
refused promotion + rich DB basis -> HardWorld fact     refused
independent authority + DB basis -> auditable promotion allowed
```

The basis adapter has no promotion-minting route. Database success, retry count, transaction identity and commit status remain provenance rather than authority.

## v0.30-work: logical transaction vs physical retry provenance

`v0.30-work` is an incremental descendant of v0.29-work on the same `oorexxapis(20260824-191338).zip/current/` upstream set. It consumes Database Core v0.43's logical transaction identity and ordered retry-attempt trail without moving database execution semantics into RYTA.

```text
logical transaction != retry attempt
retry evidence       != business action
database provenance  != HardWorld / Legal / EvidencePromotion authority
```

`DatabaseTransactionEvidenceAdapter` validates the public transaction/attempt contract, snapshots scalar attempt evidence, preserves native Database result/attempt/context objects as provenance, and refuses attached rich evidence that has no explicit semantic/execution/canonical identity. There is deliberately no `object~string` fallback.

Equivalent logical transaction/attempt evidence projected through different Alchemy adapter objects has the same deterministic evidence identity. A different logical transaction id produces a different evidence identity. Mutation of Database Core's source `attempts` Array after capture cannot rewrite the detached RYTA snapshot.

The adapter exposes an explicit `promotionsFrom()` refusal (`DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY`) and `promotionEligible=false`. Database retries may later be cited by an independent authority-bearing promotion as supporting evidence; they do not mint authority themselves.

## v0.29-work: cooperative observability without authority drift

`v0.29-work` rebases the exact v0.28-work descendant on `oorexxapis(20260824-191338).zip` and advances the RYTA house contract to Alchemy Objects v0.8. The new Alchemy release can cooperate with an already-active generic method-interposition coordinator instead of overwriting its physical wrapper.

RYTA keeps Logging optional. `integration/RYTALoggingIntegration.cls` supplies a logged VirtualRYTA subtype only for hosts that load ooRexx Logging v0.5. The core `VirtualRYTA` / `RYTAObject` dependency closure does not require Logging.

The authority rule is:

```text
method interposition / logging / telemetry = observation infrastructure
                                         != HardWorld decision authority
                                         != Legal authority
                                         != EvidencePromotion authority
```

Both real layering orders are executable: Logging-first lets Alchemy join the existing coordinator so one physical wrapper has two independently releasable providers; Alchemy-first lets Logging preserve the direct Alchemy layer, and Alchemy fails safe if asked to tear that layer out while Logging still owns the outer wrapper. In both cases RYTA decision state/winner/tier/execution status remain equal to an uninstrumented baseline.

A RYTA-specific adapter detail is deliberate: ooRexx object-specific method wrappers execute at object scope, so copying an inherited stateful `VirtualRYTA~evaluate` method would lose access to VirtualRYTA's class-scoped object variables. `RYTALoggedVirtualRYTA` therefore declares a tiny forwarding `evaluate` method and re-enters the original method with explicit `.VirtualRYTA` scope. This is an integration boundary, not a modification to Logging or Alchemy.

The canonical upstream set advances to Alchemy Objects v0.8, Runtime Registry v0.14, Camera v0.41 and Database Core v0.43 while retaining Legal Effect v0.14, Queue Fabric v0.9-dev4, Structured Relation v0.9 and NoSQLServer v0.77. Camera's RYTA bridge is green on Alchemy v0.8; Camera v0.41's own focused execution-provenance fixture still hard-asserts base version 0.7 and is therefore recorded as an upstream qualification mismatch rather than patched.

## v0.28-work: contemporary house-base and Legal analysis boundary

`v0.28-work` carries the authenticated Queue authority ledger from v0.27 onto the current API roll-up and adopts Alchemy Objects v0.7's preferred construction/provenance model. Long-lived RYTA objects enter the house base through `INIT:SUPER`; hot scalar/value records remain deliberately lightweight.

The house rule remains:

```text
Alchemy construction / introspection / execution provenance != authority
```

Legal Effect v0.14 adds deterministic counterfactual/sensitivity analysis. RYTA preserves it only through `LegalEffectV014CounterfactualEvidenceAdapter`:

```text
Legal counterfactual comparison
        | hypothetical=true
        | authoritative=false
        | assumption authority=COUNTERFACTUAL_ASSUMPTION
        v
RYTA counterfactual evidence
        | deterministic canonical identity
        | native Legal object retained as provenance
        X
EvidencePromotion / HardWorld authority
```

The adapter has an explicit promotion refusal; a hypothetical alternative result is useful analysis, not authority to mutate the real world. See `docs/LEGAL_EFFECT_V014_COUNTERFACTUAL_NON_AUTHORITY_V0.28.md` and `tests/test_legal_v014_counterfactual_boundary_v028.rex`.

The current companion API baseline is hash-pinned in `CURRENT_STACK_LOCK.sha256`; the outer roll-up SHA-256 is `bdfe9b499bdb4911160b634a6bfa0feb168f786b62fba66a89017e77c417a489`.

---

**Status: working integration checkpoint; sealed v0.23 remains the release checkpoint.**

This cut consumes `oorexxapis(20260824-162718).zip/current/` read-only. The directly exercised authority/data stack is:

```text
alchemy_objects_v0.7
oorexx_crypto_v0.1
camera_behaviour_oorexx_v0.40
structured_relation_plugin_v0.9
legal_effect_v0.14              (live authority API remains legal.effect/0.10)
runtime_registry_v0.13
oorexx_queue_fabric_v0.9-dev4
nosqlserver_v0.77
oorexx_db_skeleton_v0_42
msqlshim_v0.19
ooRexx 5.3.0 r13196
```

`RYTAObject` subclasses Alchemy `AlchemyObject` for long-lived RYTA service/state/authority-bearing objects and now uses the preferred v0.7 `INIT:SUPER` construction chain. It provides common identity, construction/execution provenance, contracts, telemetry, disclosure/introspection and Security Manager/capability surfaces without becoming a source of decision authority. Hot scalar/value records remain deliberately lightweight; their owning Alchemy object describes and exposes them.

Native live Legal authority still requires host source-authority trust verification. `LegalEffectV010PromotionAdapter` accepts only a runtime envelope carrying successful host verification evidence and emits `LEGAL_EFFECT/0.10/...+sourceauth:<hash>`. Legal Effect v0.14's new counterfactual surface is intentionally routed to evidence-only projection instead. The older v0.7 adapter remains for compatibility/offline evidence paths. The known reducer-order ambiguity still reproduces, so `LEGAL_STATUS_REDUCTION_AMBIGUOUS` remains mandatory.

See `tests/test_alchemy_v07_adoption_v028.rex`, `tests/test_legal_v014_counterfactual_boundary_v028.rex`, `tests/run_legal_effect_v010_native_promotion.sh`, and `tests/run_current_stack_rollup_v028.sh`. Exact upstream archive identities are pinned in `CURRENT_STACK_LOCK.sha256`.


## Authenticated authority ledger (v0.27-work)

`QueueAuthorityExecutionLedger` now supports `RYTA_QUEUE_AUTHORITY_LEDGER_V3`. When a host supplies a `CryptoMacKeyRing`, every new START/COMPLETE record is SipHash-2-4-128 MAC authenticated through the shared `oorexx_crypto_v0.1` public key-ring surface and chained to the previous V3 tag. The key material remains outside RYTA.

Only a verified V3 `COMPLETE` can authorize ACK-only recovery. V1/V2 records remain parseable for provenance and migration, but current execution refuses to use them as recovery authority. An unkeyed compatibility ledger may still carry a fresh side effect through START/COMPLETE/ACK, but if ACK fails, the plaintext COMPLETE requires operator recovery rather than automatic trust.

The chain protects against record injection, modification and reordering. It does **not** by itself prove that a newer valid tail was not rolled back. `chainCheckpointText` therefore exposes a compact head value for retention in a separate trusted or monotonic host store; reopening with that expected checkpoint fails closed on mismatch.

See `docs/QUEUE_AUTHORITY_LEDGER_AUTHENTICATION_V0.27.md`, `tests/test_queue_authority_ledger_auth_v027.rex`, `tests/test_queue_authority_transport_v027.rex`, and `tests/test_legal_v010_ledger_auth_v027.rex`.

## Authority lifetime / completed-work handoff (v0.26-work)

v0.26 splits the durable identity of the submitted Queue work from the consumer-time authority decision used to perform it.

`QueueAuthorityExecutionLedger` now writes V2 records with two fingerprints:

```text
work envelope fingerprint      stable submitted work
authority decision fingerprint exact authority applied
```

Before any retained-event revalidation, the executor checks the immutable work envelope against the durable ledger. A matching `COMPLETE` record means the HardWorld side effect has already happened; the retry performs ACK-only transport cleanup without calling the revalidator, without applying promotions and without minting new authority evidence. A mismatched publisher promotion set is refused as `WORK_ENVELOPE_CONFLICT`.

Successful `QueueAuthorityRevalidationResult` objects are also bound to the current `workExecutionKey` and an `attemptIdentity` derived from non-secret Queue Fabric claim evidence. This prevents a cached result from one package/subscriber or delivery attempt being handed to another. The bearer-like `claimToken` remains excluded.

The native Legal Effect v0.10 adversary proves the intended lifetime rule: authority can be valid at the moment a side effect reaches durable `COMPLETE`, ACK can fail, the Legal runtime lease can then be released, and redelivery still performs ACK-only recovery. A *different* retained work item after release remains refused by fresh Legal evaluation.

See `docs/AUTHORITY_LIFETIME_V0.26.md`, `tests/test_queue_authority_lifetime_v026.rex`, and `tests/test_legal_v010_authority_lifetime_v026.rex`.

## Retained-event authority boundary (v0.25-work)

Queue Fabric retained replay is now treated as transport/provenance evidence, never as preservation of publisher-time authority. A package carrying Queue Fabric's native `oqf.topic.retained=1` header must be consumer-time revalidated before the RYTA execution ledger can record `START`.

`QueueAuthorityPromotionExecutor` requires a `QueueAuthorityRevalidationResult` bound to the native `oqf.topic.publication_id`, a canonical consumer context, a revalidator identity and a **distinct** sealed promotion set. Returning the publisher set itself or a canonical copy of the same publisher authority is refused.

For Legal Effect v0.10, `LegalEffectV010RetainedAuthorityRevalidator` owns the actual consumer-time evaluation. It receives a live Legal engine/lease plus action/context; it does not accept a precomputed execution envelope. RYTA pins the action/context before the live call, derives the consumer-context identity from that canonical snapshot, re-pins afterward, and projects only the fresh runtime-bound result. A released lease therefore cannot reuse an earlier successful envelope.

See `docs/RETAINED_AUTHORITY_REVALIDATION_V0.25.md`, `tests/test_retained_authority_revalidation_v025.rex`, and `tests/test_legal_v010_retained_authority_v025.rex`.

---

## Inherited v0.20 authority stack

v0.20 advances the authority-bearing Legal Effect bridge from the v0.19 / Legal Effect v0.6 line to a **native Legal Effect v0.7** path while preserving the v0.19 verifier/compiler hardening.

The release also closes a rich-evidence gap exposed by Structured Relation v0.8 code-analysis findings: ordered diagnostic evidence and counter-evidence objects can now be canonically pinned from explicit revision/span/Git-object identities without flattening or implicit stringification.

## Current companion stack exercised for v0.20

```text
structured_relation_plugin_v0.8
runtime_registry_v0.8
legal_effect_v0.7
virtual_ryta_hardworld_v0.20
nosqlserver_v0.71              (focused promotion/SQL boundary)
ooRexx 5.3.0 r13196
```

The supplied `virtual_ryta_hardworld_v0.19` archive is the immutable base for this cut. Companion packages are consumed read-only and are not vendored.

## Native Legal Effect v0.7 authority

Authority-bearing promotion now uses `LegalEffectV07PromotionAdapter` and a truthful namespace:

```text
LEGAL_EFFECT/0.7/<generation>
  @<semantic-identity-hash>
  +<execution-order-hash>
  +cert:<compiler-certificate-hash>
  +verified:<verification-closure-hash>
```

The four identities remain distinct:

1. **legal semantic identity** — the sealed normative/authority graph;
2. **execution identity** — a conservative fingerprint of order still observable by the current reducer;
3. **compiler certificate identity** — compiler/input/certification closure;
4. **verification closure** — verifier-issued source/provision evidence checked against detached certificate snapshots.

Runtime Registry identity is deliberately excluded from the legal authority string.

## Verifier closure retained from v0.19

v0.20 does not regress to a boolean `cryptographicallyVerified` check. For every source and provision, the adapter requires live `verificationEvidence`, requires a corresponding compiler-certificate snapshot, and checks the two field-for-field:

```text
subject kind
source/provision/expression identity
locator
algorithm
expected digest
actual digest
verified/status
representation
material length
verifier id
verification time
parent-source evidence linkage
```

Promotion basis includes both the verified semantic identity and the detached verifier snapshot:

```text
LEGAL_VERIFIED_SOURCE
LEGAL_SOURCE_VERIFICATION_EVIDENCE
LEGAL_VERIFIED_PROVISION
LEGAL_PROVISION_VERIFICATION_EVIDENCE
LEGAL_COMPILATION_CERTIFICATE
```

The verifier snapshot retains the original native legal-source object supplied to Legal Effect.

## Runtime Registry v0.8 provenance is basis, not authority

When a Legal Effect v0.7 assessment is produced through the Runtime Registry bridge, promotion additionally retains:

```text
LEGAL_RUNTIME_EXECUTION
UPSTREAM_RUNTIME_EXECUTION
```

These point to detached `RuntimeExecutionEvidence` objects. A change in runtime generation/artifact changes provenance, not legal authority, when the certified legal graph is otherwise the same.

The focused runtime test proves the runtime evidence survives lease release.

## Structured Relation v0.8 Git/code evidence

The public Bitcoin Core PR #35688 corpus is exercised through Structured Relation v0.8. Both carried source snapshots are verified against Git blob object identity before entering the legal/business evidence chain:

```text
base  0796bbeb3271a210ed7ed5d85a82fc76939db61a
head  d9e16f361107c6d66f32ad8050c658d3b01f9241
state GIT_BLOB_BOUND
```

The derived business finding is:

```text
BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED
```

A separately source-verified, compiler-certified Legal Effect v0.7 policy requires review for that finding. The resulting HardWorld fact is `LEGAL_ACTION_REVIEW_REQUIRED`, and its retained evidence can still walk back to the exact `CodeSemanticChange` and both bound Git blobs.

## Complex diagnostic canonicalisation without flattening

Structured Relation code findings carry ordered `evidence` / `counterEvidence` arrays containing semantic nodes, guards, value-flow constraints, spans and remote revisions. v0.19's rich adapter correctly refused these because they lacked a supported canonical contract.

v0.20 adds `STRUCTURED_DIAGNOSTIC_V2` canonicalisation. Native objects remain untouched; semantic pinning is derived only from explicit public surfaces such as:

```text
repository / revision / path
claimed + computed Git blob identity and verification state
source span and lexical source
symbol qualified name
operation kind / callee
guard condition
value-flow subject/operator/bound
before/after semantic operation identity
```

Ordered arrays remain ordered. Map keys are sorted. Observation timestamps such as `createdAt`, `timestamp` and `retrievedAt` remain provenance-only and do not perturb semantic identity.

No generic object `string` fallback is used.

## Reducer ambiguity remains fail-closed

The known Legal Effect reducer-order adversary still reproduces under v0.7: ungrouped `REVIEW/STATUS_EFFECT` plus `REQUIRES_OBLIGATION` can reduce differently when norm load order changes despite identical insertion-order-independent semantic identity.

HardWorld continues to refuse authority promotion with:

```text
LEGAL_STATUS_REDUCTION_AMBIGUOUS
```

v0.20 does not invent legal precedence.

## NoSQL boundary

The new v0.7 promotion relation is exercised through stock NoSQLServer v0.71:

```text
registration / metadata       provider executions = 0
first SELECT                   provider executions = 1
basis reads                    provider executions = 1
UPDATE attempt                 SQLUNSUPPORTED
HardWorld apply                explicit EvidencePromotionApplier operation
```

The normalized SQL basis exposes source/provision verifier snapshots as retained native objects. SQL inspection remains observational and cannot apply a promotion.

## Backward compatibility

The complete v0.19 self-contained suite remains green. The Legal Effect v0.6 adapter and its focused verifier/compiler, identity, authority-basis and retained-object-drift tests remain green against Legal Effect v0.6.

v0.20 therefore adds the v0.7 bridge rather than replacing the v0.6 historical adapter.

## Trust-boundary non-claims

1. A digest match proves equality to an expected digest for an explicit representation; it does not establish who supplied that expected digest or that retrieval was authoritative.
2. Runtime execution provenance is not legal authority.
3. Structured business/code evidence is not itself normative authority merely because Legal Effect consumes it.
4. `GIT_BLOB_BOUND` proves the carried bytes match the claimed Git blob object ID; it does not by itself prove the repository/commit was endorsed by any authority.
5. The Legal Effect reducer-order ambiguity remains an upstream semantic ambiguity and is refused, not repaired, here.
6. No companion package is modified or vendored into HardWorld.

See `VALIDATION.md`, `CHANGELOG.md`, and `docs/LEGAL_EFFECT_V07_PROMOTION_V0.20.md`.
