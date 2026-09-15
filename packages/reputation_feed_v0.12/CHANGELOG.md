# Changelog

## 0.12 — 2026-08-24

- Advanced runtime API to `reputation.feed/0.12` and generation label `REPUTATION-FEED-V0.12`.
- Added sealed `ReputationFeedDecisionTrace` governed-execution evidence with exact policy/deployment identity, threshold/count facts and bounded provenance reason summaries.
- Decision traces intentionally exclude raw claim/customer/source content; they are audit evidence, not reputational dispositions.
- Added independent Queue persistence identity `reputation.feed.decision-trace/1` and canonical `reputation/feed/decisions/...` transport with `GOVERNED_DECISION_AUDIT_NOT_DISPOSITION`.
- Added optional `ReputationFeedLoggingBridge` for ooRexx Logging v0.5; Feed supplies the exact trace payload while Logging retains authority over scopes, rules, targets, retention and logging policy.
- Extended Queue restart acceptance from six to seven durable Feed payload families.

## 0.11 — 2026-08-24

- Advanced runtime API to `reputation.feed/0.11` and generation label `REPUTATION-FEED-V0.11`.
- Migrated the Feed house foundation to Alchemy Objects v0.8 while retaining preferred `INIT` super-chain construction and STANDARD adoption.
- Advanced the optional Institutional Policy dependency to v0.6.
- Added topology-aware `operativeForContext()` using service/region/channel/tenant/cohort deployment points.
- Routed legacy `operative(catalog,time)` through the topology-aware resolver so configured topology cannot be bypassed by omitting context.
- Added `ReputationFeedPolicyDeploymentEvidence` retaining exact topology mode/source, deployment point, immutable binding and active progressive-rollout authority evidence.
- Added bounded progressive v1/v2 rollout acceptance covering ordinary-v1 versus pilot-v2 canary, cutover, exact-policy rollback, historical replay and authorization expiry.
- Extended governed Feed -> Effect promotion metadata with exact deployment and progressive-rollout evidence.
- Revalidated the full inherited Feed suite against Runtime Registry v0.14, Queue Fabric v0.9-dev4, Reputation Effect API 0.2, Interaction Event v0.3 and Structured Utterance v0.3.
- Re-ran Structured Utterance v0.3's native Interaction Event bridge against Interaction Event v0.3; the previous v0.2 missing-native-evidence compatibility defect is resolved in the current API closure.

## 0.10 — 2026-08-24

- Advanced package/API/generation identity to `0.10`, `reputation.feed/0.10`, and `REPUTATION-FEED-V0.10`.
- Added sealed `ReputationFeedPolicySet` containing domain-owned lineage, corroboration, provenance-eligibility and geographic-salience policy objects.
- Added optional Institutional Policy v0.3 governance bridge for fixed/reviewable policy release, exact effective-dated handover, publication evidence, historical operative replay and explicit counterfactual evaluation.
- Added `ReputationFeedGovernedOutcome` and `ReputationFeedPolicyExecution`, retaining exact release identity, policy-set identity, action time, evaluation mode and publication assurance with every governed result.
- Added deterministic canonical forms for lineage and event-cluster results so governed policy outcomes have stable identities beyond corroboration/salience assessments.
- Added governed Reputation Effect promotion. Only `OPERATIVE + CORROBORATED` policy execution can emit observations; counterfactual execution is fail-closed with `COUNTERFACTUAL_NOT_PROMOTABLE`.
- Effect evidence anchors promoted through the governed bridge retain exact Feed policy reference, institutional release identity, Feed policy-set identity, evaluation mode and assurance level.
- Preserved plain direct-policy APIs and kept Institutional Policy/Reputation Effect as optional integration dependencies rather than core requirements.
- Requalified complete Feed behaviour against Runtime Registry v0.14; its core `runtime.registry/0.3` contract remains stable.

## 0.9 — 2026-08-24

- Advanced package/API/generation identity to `0.9`, `reputation.feed/0.9`, and `REPUTATION-FEED-V0.9`.
- Added `ReputationInteractionEvidencePacket` plus rich content, assessment and relationship evidence objects.
- Added independent optional bridges from Interaction Event v0.2 and Structured Utterance v0.3; both enforce a de-identified analytical projection before Feed ingestion.
- Structured Utterance ingestion preserves segment boundaries, communicative purpose, data roles, effective information-use findings, generation intents and stable evidence points without copying raw customer lineage references.
- Interaction Event ingestion preserves projected content, projected actor/subject references, assessments, correlations, evidence anchors and explicit causal-status links; assessments remain assessments and `CANDIDATE_NOT_PROVEN` remains candidate evidence.
- Added `ReputationInteractionClaimSpec` and `ReputationFeedInteractionClaimBridge`; an explicit assertion root is mandatory before interaction evidence can become a Feed claim.
- Added regression proving Structured Utterance + Interaction Event representations of the same conversation count as one assertion family and cannot self-corroborate.
- Added Queue topic `reputation/feed/interactions/...`, authority boundary `PRIVACY_PROJECTED_INTERACTION_EVIDENCE_NOT_DISPOSITION`, persistence identity `reputation.feed.interaction-evidence/1`, codec registration and restart recovery.
- Added Alchemy v0.7 state disclosure/adoption coverage for the interaction evidence family.
- Recorded the supplied Structured Utterance v0.3 -> Interaction Event v0.2 optional-bridge incompatibility instead of hiding it inside Feed.
- Fixed package hygiene: Queue Fabric persistence tests now clean their temporary journal directories so test debris is not shipped.


## 0.8 — 2026-08-24

- Advanced runtime API to `reputation.feed/0.8` and generation label `REPUTATION-FEED-V0.8`.
- Added explicit Queue Graph persistence identities and restore contracts for raw envelopes, claims, event hypotheses, corrections and watch matches.
- Added `ReputationFeedQueuePersistenceSupport` and caller-context-aware restore factories; types must be registered before Queue Fabric recovery.
- Durable persistence projects only domain state at the queue boundary. Alchemy sealer/authority/runtime telemetry are not journaled.
- Added direct graph-codec round-trip tests and real permanent topic/queue restart + retained-publication recovery tests.
- Preserved the v0.7 publish-only Queue administration boundary: Feed still does not create queues/topics/subscriptions/ACLs/security domains.

## 0.7 — 2026-08-24

- Advanced runtime API to `reputation.feed/0.7` and generation label `REPUTATION-FEED-V0.7`.
- Adopted Alchemy Objects v0.7 and migrated the centralized Feed house constructor from compatibility `initAlchemy()` to the preferred non-virtual `INIT` path.
- Added optional `ReputationFeedQueueBridge` integration for Queue Fabric v0.9 object-graph topic publication.
- Added canonical `reputation/feed` routing for raw envelopes, claims, event hypotheses, corrections and watch alerts while retaining explicit authority-boundary headers.
- Kept Queue Fabric wiring authority external: the bridge cannot create topics, queues, subscriptions, ACLs, security domains, retention rules or peers.
- Added fail-closed `REPUTATION_FEED_PERSISTENCE_ADAPTER_REQUIRED` for persistent/retained publication until explicit Feed queue restore factories exist; no rich domain object is flattened merely to satisfy transport.
- Added Queue bridge Alchemy v0.7 adoption and exact object-identity transport acceptance.
- Fixed `ReputationFeedClaim~addSubject()` to propagate the caller Alchemy context into child subject-link objects.
- Revalidated the complete v0.6 behavioural suite against Runtime Registry v0.13 and Reputation Effect API 0.2.

## 0.6 — 2026-08-24

- Advanced runtime API to `reputation.feed/0.6` and generation label `REPUTATION-FEED-V0.6`.
- Added claim-level `ReputationAssertionOriginLink` ancestry evidence so independent publication surfaces can still collapse to one underlying primary assertion family.
- Added explicit `assertionOriginFamilyId`, `assertionAncestryResolved`, ancestry-link retention, and deterministic `corroborationFamilyId` on `ReputationFeedClaim`.
- Preserved legacy behaviour through explicit `PUBLICATION:<family>` fallback when Librarian has not resolved assertion ancestry; no ancestry is invented.
- Extended `ReputationLibrarianFinding` and `ReputationLibrarianClaimBridge` to carry rich assertion-origin evidence from Librarian into sealed claims.
- Corroboration and contest thresholds now count effective assertion families when ancestry is known, preventing independent mastheads that repeat the same press release/quote from manufacturing corroboration or contested state.
- Extended corroboration evidence/assessment packets with publication-family count, explicit assertion-origin-family count, resolved/fallback claim counts, and per-claim publication versus assertion family evidence.
- Hardened the hypothesis→Effect bridge to emit one representative observation per effective assertion family and retain publication/assertion/corroboration family metadata independently.
- Added regressions for Boeing press-release reuse across Reuters/BBC/local variants, independent FAA confirmation, duplicate denial ancestry, legacy fallback, Librarian ancestry propagation, and Effect promotion deduplication.

## 0.5 — 2026-08-23

- Advanced runtime API to `reputation.feed/0.5` and generation label `REPUTATION-FEED-V0.5`.
- Added provenance-aware corroboration eligibility with explicit `ELIGIBLE` versus `DISCOVERY_ONLY` evidence status per claim.
- Failed source authentication and attached compromised-source history are retained as evidence but do not count as corroborating lineage families by default.
- Unverified and legacy/unassessed origin remain eligible by default for compatibility with ordinary public feeds, but the policy reason is retained explicitly.
- Added explicit policy overrides for failed authentication and compromised-source evidence without introducing a numerical trust/reliability score.
- Extended corroboration assessments with eligible/discovery-only claim and family counts plus canonical provenance evidence.
- Prevented failed-authentication denials from manufacturing `CONTESTED` state under default policy.
- Propagated source-history compromise/evidence identity from `ReputationSourceEvidencePacket` into normalized claims without changing Librarian confidence.
- Hardened hypothesis-to-Effect promotion so only provenance-eligible representative families are emitted; explicit permissive policy is required to promote failed/compromised evidence.
- Added source-authentication/source-history metadata to Effect evidence anchors.

## 0.4 — 2026-08-23

- Advanced the runtime API to `reputation.feed/0.4` and generation label `REPUTATION-FEED-V0.4`.
- Adopted Alchemy Objects v0.5 STANDARD metadata/inheritance verification.
- Added detached source-origin authentication with time-bounded source/key/endpoint/locator bindings.
- Added caller-owned SipHash-128 verification and public-key Ed25519 proof support without storing source private keys in Feed.
- Added append-only source-history events and deterministic as-of replay for authentication, key rotation, endpoint changes, corrections, retractions, compromise declarations and restoration.
- Added rich `ReputationSourceEvidencePacket` objects.
- Extended Librarian claim promotion to retain source-authentication state and evidence identity without modifying content confidence.
- Explicitly retained the invariant: authenticated origin is provenance evidence, not assertion truth, and there is no universal source trust score.
- Updated Runtime Registry factories for source authenticator/history ledger.
- Moved routine Alchemy adoption checks to the v0.5 adoption verifier rather than repeatedly MAC-sealing large introspection payloads in every Feed regression.

## 0.3 — 2026-08-23

- Advanced the public runtime API to `reputation.feed/0.3` and generation label `REPUTATION-FEED-V0.3`.
- Added sealed `ReputationSourceIdentity` and `ReputationRawEnvelope` acquisition primitives with separate receive/source times, locator, content type, caller-supplied payload digest, ordered retained segments and source fields.
- Added normalized `ReputationAcquiredDocument`, paragraph-bearing `ReputationLibrarianHandoff`, explicit `ReputationLibrarianFinding`, and deterministic `ReputationLibrarianClaimBridge`.
- Added `ReputationNewsPublicationAdapter`, `ReputationOfficialNoticeAdapter`, `ReputationPublicStreamAdapter`, and `ReputationAcquisitionRouter`.
- News acquisition creates a lineage-capable publication article/surface but leaves reach/range absent unless separately evidenced. Official/public-stream acquisition does not masquerade as independent news publication.
- Source kind, evidential role, publisher group and ownership group remain descriptive metadata and are not trust scores or independent-source votes.
- Caller-supplied Alchemy security/evidence context is propagated through adapter-created child objects.
- Added end-to-end acquisition -> Librarian finding -> Feed claim -> corroborated hypothesis acceptance, plus adapter-diversity and cryptographically sealed acquisition-base tests.
- Cleaned duplicate `eventKey` state/canonical lines and a duplicated paragraph-score assignment left in the v0.2 source without changing their semantics.

## 0.2 — 2026-08-23

- Advanced the runtime API to `reputation.feed/0.2` and generation label `REPUTATION-FEED-V0.2`.
- Added normalized `ReputationFeedClaim` objects carrying lineage family, event type/key, stance, confidence, source identity, subjects, concepts, observed geography and affected geography.
- Added deterministic event-hypothesis clustering with time/subject/concept evidence and an optional normalized event key as a hard anti-overmerge boundary.
- Added `ReputationCorroborationPolicy` and `ReputationCorroborationAssessment`; reports retain actual independent-family counts, required-family threshold, family-normalised confidence, required confidence, denial-family count, contested state and status.
- Corroboration counts independent lineage families rather than publication/article count; AI rewrites from one lineage contribute one family vote.
- Added assertion-vs-denial handling with explicit `CONTESTED` status.
- Added correction/retraction/supersession ledger and historical replay; corrections alter current state without deleting earlier knowledge.
- Added watchsets and deterministic watch matching over event type, subject, concept and affected geography.
- Added geography-specific salience evidence/threshold assessment without assigning reputational direction.
- Extended Feed→Effect integration with corroborated-hypothesis promotion to one representative `ReputationObservation` per independent assertion family/geography; uncorroborated hypotheses are blocked by default and require explicit caller override.
- Fixed a latent sparse-array BFS defect in the original lineage connected-component traversal and added branching-lineage regression coverage.
- Added new AlchemyObject sealed-introspection acceptance for claim/hypothesis/cluster objects.

## 0.1.1 — 2026-08-23

- Migrated every non-static Reputation Feed domain class onto `ReputationFeedAlchemyObject`, which subclasses `AlchemyObject` v0.4.3.
- Preserved the public runtime API `reputation.feed/0.1` and generation label `REPUTATION-FEED-V0.1`.
- Added stable Alchemy identity, lifecycle/use telemetry, contracts, state descriptions, dependency evidence, security-runtime evidence, and optional sealed introspection.
- Added optional final `ReputationFeedAlchemyContext` constructor argument for caller-supplied Alchemy evidence sealer/capability authority without breaking existing constructor calls.
- Registered lineage/reach/range identity fields for bounded disclosure.
- `ReputationLineageEngine~group()` and the Feed→Effect bridge now emit inherited usage telemetry.
- Runtime module inherits the house base and exposes package/base version evidence.
- Added executable inheritance and sealed-introspection tests and revalidated Runtime Registry v0.12 plus the Feed→Effect bridge.

## 0.1 — 2026-08-22

- Initial independent reputation-feed/acquisition domain.
- First-class separation of publication surface count, validated reach, geographic range and independent lineage family count.
- Paragraph-by-paragraph Librarian comparison contract tied to a named custom corpus.
- Multi-axis similarity: lexical, semantic, claims, entities, numeric facts, temporal facts and paragraph role.
- Article-level sequence alignment and rare-fact overlap.
- Deterministic lineage cut and transitive connected-component grouping.
- Reach evidence requires provenance/time/confidence; missing evidence remains incomplete.
- Range evidence is provenance-bearing and kept separate from reach.
- Optional Feed -> Effect bridge promotes lineage-bearing evidence only to `ReputationObservation`.
- Runtime Registry v0.11 publication module and acceptance test.
