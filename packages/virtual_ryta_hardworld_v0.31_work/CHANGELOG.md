# Changelog

## v0.31-work

- Added `DatabaseTransactionPromotionBasisAdapter`: detached Database Core transaction/retry evidence may be cited as auditable `EvidencePromotionBasis`, but cannot directly mint `EvidencePromotion`.
- Basis identity is the v0.30 deterministic database evidence identity and therefore excludes Alchemy adapter object identity.
- Added adversary proving a REFUSED promotion remains skipped even when it carries successful committed database evidence.
- Added positive audit case proving the same database evidence can accompany an independently authorized promotion without becoming its authority source.
- Retained all v0.30 transaction/retry provenance, Queue/Legal authority-lifetime, authenticated-ledger and observability boundaries unchanged.

## v0.30-work

- Added `DatabaseTransactionEvidenceAdapter` for Database Core v0.43 logical transaction and physical retry-attempt provenance. Database Core remains external/read-only.
- Enforced one logical transaction id across the ordered attempt trail and Database Core's public `<transaction>:attempt:<n>` identity contract.
- Added detached transaction/attempt evidence while retaining native Database result/context/attempt objects as provenance.
- Refused implicit stringification of rich execution-context evidence; attached evidence must expose an explicit deterministic identity.
- Added source-drift and poisoned-`STRING` regressions.
- Added explicit `DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY` promotion refusal and `promotionEligible=false`.
- Retained the v0.29 Alchemy v0.8 / Logging v0.5 cooperative-interposition boundary unchanged and the same canonical upstream set.

## v0.29-work

- Rebased the exact v0.28-work descendant on `oorexxapis(20260824-191338).zip`; `CURRENT_STACK_LOCK.sha256` now pins 47 non-RYTA members and the bundled v0.28-work archive is the byte-identical source ancestor.
- Advanced RYTA-owned long-lived/state/authority-bearing objects to Alchemy Objects v0.8 / `ALCHEMY-HOUSE-OBJECT-0.8`, retaining preferred `INIT:SUPER` construction and the rule that Alchemy identity, telemetry, introspection and method interposition are evidence infrastructure, not authority.
- Added optional `RYTALoggingIntegration.cls` for ooRexx Logging v0.5. Logging remains outside the RYTA core dependency closure.
- Added real two-order cooperative-interposition acceptance around `VirtualRYTA~evaluate`: Logging-first yields one physical wrapper/two providers and independent Alchemy withdrawal; Alchemy-first preserves the direct Alchemy layer and refuses destructive removal with `TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE` until Logging releases.
- Added an explicit scoped forwarding surface in `RYTALoggedVirtualRYTA` because ooRexx object-specific wrappers cannot safely copy an inherited stateful method and retain the declaring class's object-variable scope.
- Proved interposition order/installation/removal does not change RYTA state, winning rule, winning tier, execution status or output count, and Alchemy execution evidence still retains argument count rather than the raw world argument.
- Requalified native Legal v0.14 / Registry v0.14, Queue Fabric v0.9-dev4, Camera v0.41 bridge, Structured Relation v0.9 and NoSQLServer v0.77 paths. Runtime Registry v0.14 retains `runtime.registry/0.3`; its detached execution-evidence regression remains 24/24.
- Recorded an upstream Camera v0.41 qualification mismatch: its own execution-provenance fixture requires Alchemy base `0.7`, while the canonical roll-up supplies v0.8. RYTA's Camera bridge passes unchanged; no Camera source was modified.
- Qualified Database Core v0.43 transaction identity, retry-attempt context, relational-source and conformance-failure smoke tests as supporting current SQL/provenance evidence.
- Retained the Legal reducer-order guard, retained-event consumer-time authority boundary, authority-lifetime split and authenticated Queue ledger unchanged.

## v0.28-work

- Rebased the v0.27 authenticated-ledger descendant onto `oorexxapis(20260824-162718).zip` while preserving all upstream packages read-only.
- Migrated RYTA-owned long-lived/state/authority-bearing objects from Alchemy's compatibility `initAlchemy` path to the Alchemy Objects v0.7 preferred `INIT:SUPER` construction chain. RYTA now reports STANDARD adoption with construction provenance `INIT/base-0.7`; the legacy `rytaInitAlchemy` method remains only as a compatibility message for downstream subclasses.
- Added explicit STANDARD package/purpose/authorship/standards/design-limitations metadata and retained the rule that Alchemy identity, telemetry and execution provenance are evidence infrastructure, not HardWorld/Legal/promotion authority.
- Added bounded execution-provenance acceptance for `VirtualRYTA~evaluate()`: method contract/revision/outcome/argument count may be observed, while raw world arguments and Alchemy object ids remain outside deterministic decision identity.
- Added `LegalEffectV014CounterfactualEvidenceAdapter`. Legal Effect v0.14 counterfactual comparisons are projected as deterministic evidence only when `hypothetical=true`, `authoritative=false`, and the assumption authority is `COUNTERFACTUAL_ASSUMPTION`.
- Added an explicit `LEGAL_COUNTERFACTUAL_NOT_AUTHORITY` promotion refusal. Counterfactual evidence has no `EvidencePromotionSet` surface and cannot be consumed by `EvidencePromotionApplier`. Native Legal counterfactual objects remain reachable as provenance.
- Pinned the current API roll-up (45 non-RYTA current members) in `CURRENT_STACK_LOCK.sha256`; the bundled v0.27-work RYTA archive is recorded separately as the source ancestor.
- Confirmed compatibility with Legal Effect v0.14, Runtime Registry v0.13, Queue Fabric v0.9-dev4, Camera v0.40, Structured Relation v0.9 and NoSQLServer v0.77. Legal Effect continues to expose the live `legal.effect/0.10` authority API; v0.14 counterfactual analysis is explicitly non-authoritative.
- Retained `LEGAL_STATUS_REDUCTION_AMBIGUOUS`; the known reducer-order adversary still reproduces and counterfactual analysis does not cure it.

## v0.27-work

- Added authenticated `RYTA_QUEUE_AUTHORITY_LEDGER_V3` records for Queue authority execution using a host-supplied shared `CryptoMacKeyRing` from standalone `oorexx_crypto_v0.1`; no MAC key material is persisted by RYTA.
- V3 records MAC the execution key, immutable work-envelope fingerprint, authority-decision fingerprint, attempt evidence, timestamp, chain predecessor, algorithm and key id; records are globally sequenced and chained by the previous record tag.
- Only MAC-verified V3 `COMPLETE` state can authorize automatic ACK-only recovery. Historical V1/V2 records remain readable evidence but are refused as `LEGACY_LEDGER_RECORD_UNTRUSTED` for current recovery.
- Compatibility mode may still execute fresh work with an unkeyed V2 ledger, but a later retry cannot treat that plaintext completion as recovery authority.
- Added key-rotation support: each V3 record carries algorithm/key-id/tag and old keys remain required to verify historical records. Legacy writes are disabled once an authenticated ledger/keyring is in use.
- Added adversaries for forged `COMPLETE`, record mutation, record reordering, missing historical keys, missing keyring, V2 recovery downgrade, and claim-token leakage.
- Added `chainCheckpointText` / `matchesCheckpoint` and optional constructor checkpoint verification. This is deliberately a host trust boundary: a local MAC chain authenticates the records that are present, but only an externally retained trusted/monotonic checkpoint can detect rollback to an older valid tail.
- Replayed Queue Fabric transfer-receipt identity/idempotency under V3 and native Legal Effect v0.10 completed-work recovery after Runtime Registry lease release.
- Bumped Alchemy house metadata to `0.27-work`; sealed v0.23 remains the release checkpoint.

## v0.26-work

- Bumped the RYTA Alchemy house metadata to `0.26-work` and updated the sealed-introspection regression so public component provenance cannot lag `VERSION.txt`.
- Split Queue authority execution identity into an immutable **work envelope fingerprint** and a separate **authority decision fingerprint**.
- Added `RYTA_QUEUE_AUTHORITY_LEDGER_V2` while retaining read/execute compatibility for V1 records and the legacy `begin` / `complete` API.
- V2 performs ledger preflight before retained-event revalidation. A matching durable `COMPLETE` performs ACK-only recovery with no new authority evaluation, no `EvidencePromotionApplier` call and no new revalidation evidence.
- A changed publisher promotion set on a `COMPLETE` retry is refused as `WORK_ENVELOPE_CONFLICT`; completed state is therefore not a blind ACK oracle.
- Added per-delivery revalidation binding: successful `QueueAuthorityRevalidationResult` carries the current stable `workExecutionKey` plus an `attemptIdentity` derived from non-secret Queue claim evidence. Cached results cannot cross work identities or delivery attempts.
- Kept attempt binding outside the stable revalidation `algorithmCanonicalText`; `executionBindingCanonicalText` exposes it separately so redelivery freshness does not silently redefine the semantic authority decision.
- Added an executable cached-result adversary covering same-package redelivery and cross-subscriber/work reuse.
- Added a real Legal Effect v0.10 lifetime test: Legal authority applies, ACK is deliberately failed after durable `COMPLETE`, the runtime lease is released, and a redelivery is ACKed without re-evaluating or reapplying. New retained work after release still fails fresh Legal evaluation.
- `claimToken` remains excluded from canonical identities, fingerprints, ledger records and returned evidence. V2 remains deliberately non-XA; `START` without `COMPLETE` is still `PREVIOUS_EXECUTION_UNCERTAIN`.

## v0.25-work

- Added a first-class consumer-time authority boundary for Queue Fabric retained topic replays. Native `oqf.topic.retained=1` and `oqf.topic.publication_id` headers are used; RYTA does not invent a parallel retained-event marker.
- Retained queue work now requires a consumer revalidator before any execution-ledger `START`. Publisher-time promotion sets cannot be applied directly merely because the message is durable, signed, runtime-pinned or was once legally admissible.
- Added `QueueAuthorityRevalidationResult`, binding publication id, canonical consumer-context identity, revalidator identity and the fresh sealed promotion set into the queue work fingerprint while excluding Alchemy object ids and wall-clock observation time.
- Rejects both object-level pass-through and canonical/semantic copies of the publisher promotion set. A copied object carrying identical publisher-time authority is still stale authority.
- Added `LegalEffectV010RetainedAuthorityRevalidator`. It accepts a live Legal Effect engine/lease plus action/context and performs both the conservative pinned evaluation and the runtime-bound Legal v0.10 evaluation inside `revalidate()`; precomputed Legal execution envelopes are not accepted.
- The Legal revalidator derives the consumer context identity from RYTA's canonical Legal input snapshot, re-pins action/context after the live call, preserves `LEGAL_STATUS_REDUCTION_AMBIGUOUS`, and fails if the input changes across the authority boundary.
- Added an adversary proving a released Legal runtime lease cannot reuse a previously successful retained-event result: the fresh live evaluation returns `LEGAL_RETAINED_LIVE_EVALUATION_REFUSED` before ledger `START`.
- Retained revalidation failures remain unacked/inflight for caller policy; successful current authority is applied, durably completed, then ACKed under the existing non-XA START/COMPLETE model.
- Live topic deliveries (`oqf.topic.retained=0`) remain backward-compatible and do not require retained-event revalidation.

## v0.24-work

- Rebased the RYTA integration checkpoint on `oorexx-libs(20260822-crypto-consolidated)(7).zip/current/` while keeping every upstream package read-only.
- Added `RYTAObject`, a RYTA-owned subclass of Alchemy Objects v0.4.3 `AlchemyObject`, for long-lived service/state/authority-bearing RYTA objects. Alchemy identity, introspection and telemetry are explicitly evidence infrastructure, not HardWorld/Legal/promotion authority.
- Deliberately exempted hot scalar/value records such as `RYTAFact` and `HardWorldClause` from full Alchemy initialization after measuring the broad migration at roughly 15x the old coverage-test runtime; the narrowed boundary materially reduces that overhead.
- Added executable Alchemy-object identity/introspection tests, including MAC-sealed public introspection and proof that Alchemy object IDs do not enter promotion canonical identity or Queue authority replay keys.
- Adopted standalone `oorexx_crypto_v0.1` as the crypto source required by the new house base and current Legal Effect/Registry packages; removed the RYTA test assumption that Runtime Registry vendors `src/crypto.cls`.
- Added native `LegalEffectV010PromotionAdapter`. It requires a live Legal Effect v0.10 execution envelope with successful host source-authority verification evidence, binds that verification closure into a truthful `LEGAL_EFFECT/0.10/...+sourceauth:<hash>` authority identity, and preserves the evidence objects as promotion basis. Runtime Registry artifact/generation identities remain provenance only.
- Retained the conservative v0.7 pinned evaluator/reducer guard because the REVIEW/STATUS_EFFECT + REQUIRES_OBLIGATION order adversary still reproduces under Legal Effect v0.10.1. `LEGAL_STATUS_REDUCTION_AMBIGUOUS` is not removed.
- Confirmed Queue Fabric v0.8.2, Camera v0.36, Structured Relation v0.9 and NoSQLServer v0.75 remain compatible with the existing RYTA boundaries.
- Legacy v0.7 Structured/NoSQL promotion runners remain compatibility evidence and are labelled as such; they are not represented as native v0.10 live authority.

## v0.23

- Sealed after fresh replay of the inherited corpus, 37/37 class compilation, promoted current-stack integration, manifest verification and upstream ownership checks under ooRexx 5.3.0 r13196.
- Recovery roll-up promoted to canonical `oorexx-libs(20260822-020835).zip/current/`.
- Pinned the full promoted current inventory, including Camera v0.34, NoSQLServer
  v0.75, DB Skeleton v0.40, Queue Fabric v0.8.1, Runtime Registry v0.11,
  msqlshim v0.12, CivicPort v0.4, KL10 IPL v0.29, Terminal Machine v0.5 and
  Work Load Units v0.2.
- Confirmed Legal Effect v0.7 accepts Runtime Registry v0.11 detached
  `RuntimeLease~executionEvidence`; the former `LEGAL_RUNTIME_EVIDENCE_REQUIRED`
  recovery limitation is closed.
- Confirmed Legal runtime execution provenance remains promotion basis only and
  does not enter the `LEGAL_EFFECT/0.7/...` authority identity.
- Confirmed Queue Fabric v0.8.1 preserves the v0.21 authority/replay contract
  without relaxing START/COMPLETE crash handling or claim-token isolation.
- Replayed Queue Fabric v0.8.1 core against NoSQLServer v0.75 + Runtime Registry v0.11, including topics: all focused core suites passed with 2000/2000 concurrent deliveries and zero duplicates.
- Confirmed Camera v0.34, Structured Relation v0.9 and NoSQLServer v0.75 remain
  compatible with the existing RYTA Algorithm Relation / rich-evidence / legal
  promotion bridges.
- Retained `LEGAL_STATUS_REDUCTION_AMBIGUOUS`; Legal Effect v0.7's known reducer
  order ambiguity is not reclassified merely because runtime provenance is now
  available.
- No upstream package is patched; only the RYTA recovery descendant is changed.

## v0.22-work

- Recovery roll-up from canonical `oorexx-libs.zip/current/` rather than ad-hoc
  individual uploads.
- Reapplied the v0.20 Legal Effect v0.7 / structured diagnostic delta and the
  v0.21 Queue Fabric authority-execution delta over bundled HardWorld v0.19.
- Added `CURRENT_STACK_LOCK.sha256` to pin every canonical bundle member used by
  the recovery replay.
- Confirmed Camera v0.33 compatibility with the existing Algorithm Relation
  bridge.
- Confirmed Structured Relation v0.9 compatibility with rich-evidence, NoSQL,
  and Git/code -> Legal v0.7 -> HardWorld paths.
- Confirmed Queue Fabric v0.5 core against bundled NoSQLServer v0.73 and Runtime
  Registry v0.8: 62 acceptance, 71 adversarial, 2000/2000 concurrency with zero
  duplicates, 141 MQ, 24 NoSQL, 85 channel, and 38 channel/NoSQL assertions.
- Confirmed Runtime Registry v0.8 ability-HTTP Queue Fabric integration against
  Queue Fabric v0.5.
- Reclassified Registry hash `6b4f4c8e...42df5` as canonical for the recovery
  bundle. The old `7ef1...` sidecar is historical lineage evidence, not the
  required recovery artifact.
- Added an executable current-stack roll-up runner which treats
  `LEGAL_RUNTIME_EVIDENCE_REQUIRED` as the required fail-closed result for the
  canonical Registry's missing execution-evidence surface.
- Did not patch or shim Runtime Registry or Legal Effect and did not weaken the
  `LEGAL_STATUS_REDUCTION_AMBIGUOUS` guard.

## v0.21-work

- Base: sealed `virtual_ryta_hardworld_v0.20` archive; companion packages remain read-only.
- Added `QueueFabricAuthorityExecution.cls`, a RYTA-owned execution/replay boundary around explicit `EvidencePromotionApplier` calls.
- Uses Queue Fabric v0.5 native `packageId`, `transferId`, receipt, delivery/backout and claim-principal/time surfaces; no synthetic upstream attempt/session fields.
- Requires an explicit execution namespace because a Queue Fabric transfer receipt does not contain destination-manager identity.
- Cross-checks supplied transfer receipts against `ObjectQueueManager~transferReceipt(transferId)` before accepting transfer provenance.
- Excludes Queue Fabric `claimToken` from canonical identity, hashes, ledger storage and results; claimed package objects and raw ACK results are not retained because they keep the token reachable. Safe public transport metadata is snapshotted instead.
- Adds START/COMPLETE execution ledger with fail-closed `PREVIOUS_EXECUTION_UNCERTAIN` handling and `WORK_IDENTITY_CONFLICT` protection.
- Adds replay suppression for COMPLETE-before-ACK recovery; this is explicitly not represented as XA or exactly-once authority execution.
- Added real Queue Fabric v0.5 focused tests including durable transfer receipt recovery/replay after manager restart.
- Replayed NoSQLServer v0.73 focused JSON/join/metadata/mutation gates under ooRexx r13196.
- Detected a same-version Runtime Registry v0.8 provenance collision. The currently uploaded artifact lacks `RuntimeLease~executionEvidence`; Legal Effect v0.7 correctly fails closed with `LEGAL_RUNTIME_EVIDENCE_REQUIRED`. No upstream compatibility shim is invented.
- Retained `LEGAL_STATUS_REDUCTION_AMBIGUOUS`; the v0.7 reducer-order adversary still reproduces.

## v0.20

- Base: supplied `virtual_ryta_hardworld_v0.19` archive, manifest-verified before modification.
- Added native `LegalEffectV07PromotionAdapter` with `LEGAL_EFFECT/0.7/...` authority namespace.
- Retained v0.19's full source/provision verifier-evidence closure and compiler-certificate snapshot matching in the v0.7 adapter.
- Added normalized `LEGAL_SOURCE_VERIFICATION_EVIDENCE` and `LEGAL_PROVISION_VERIFICATION_EVIDENCE` basis rows for v0.7 promotions.
- Added Runtime Registry v0.8 execution provenance basis (`LEGAL_RUNTIME_EXECUTION`, `UPSTREAM_RUNTIME_EXECUTION`) without incorporating runtime identity into legal authority.
- Preserved the fail-closed `LEGAL_STATUS_REDUCTION_AMBIGUOUS` guard under Legal Effect v0.7.
- Extended Structured Relation rich diagnostic canonicalisation to ordered complex provenance objects (`STRUCTURED_DIAGNOSTIC_V2`) without implicit stringification.
- Added full Structured Relation v0.8 Bitcoin Git/value-flow -> Legal Effect v0.7 -> HardWorld evidence-chain test using verified public blob identities.
- Added Legal Effect v0.7 promotion relation -> NoSQLServer v0.71 read-only/lazy-materialisation integration test.
- Retained v0.6 compatibility adapter/tests unchanged in authority semantics.

## v0.19

See the inherited v0.19 validation/docs retained in this archive.
