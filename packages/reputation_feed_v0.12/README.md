# Reputation Feed v0.12

`Reputation Feed` is the acquisition/lineage companion to `Reputation Effect`.

Its job is **not** to decide whether a person, company, campaign, or event is reputationally good or bad. It answers narrower ingestion questions:

- how many publication surfaces are present;
- what audience-reach evidence is actually valid;
- what geographic range is actually evidenced;
- which apparently different articles are probably the same underlying source lineage;
- which extracted claims descend from the same underlying primary assertion even when they appear in editorially independent publications;
- how many independent assertion families remain after AI rewriting, syndication, quotation, and source reuse are collapsed;
- how privacy-projected customer/agent interaction evidence can enter the same lineage system without flattening rich conversation structure.

## Alchemy house foundation

Every non-static feed class now descends from `ReputationFeedAlchemyObject -> AlchemyObject` v0.8. The Feed therefore gets the same Alchemy identity, lifecycle/use telemetry, bounded state descriptions, method/requirement contracts, security-runtime evidence and optional cryptographically sealed introspection as the rest of the house stack.

Existing constructor calls remain valid. An optional final `ReputationFeedAlchemyContext` can carry a caller-owned evidence sealer and capability authority; no package-global key or authority is created.

The package release is `0.12`, with public runtime API `reputation.feed/0.12` and generation label `REPUTATION-FEED-V0.12`. `ReputationLineageEngine~group()` and the Feed→Effect bridge touch inherited telemetry.

## Governed decision evidence and logging boundary (v0.12)

v0.12 adds `ReputationFeedDecisionTrace`, a sealed bounded explanation object for governed Feed execution. A trace carries operation/status, exact Institutional Policy release and Feed policy-set identity, deployment/rollout evidence, threshold facts, eligible versus discovery-only evidence counts, and a sorted summary of provenance reason codes. It deliberately does **not** copy claim titles, customer text, article bodies, source payloads or other raw evidence.

Decision traces are independently persistent as `reputation.feed.decision-trace/1` and publish under `reputation/feed/decisions/<policy>/<version>/<trace>`, with authority boundary `GOVERNED_DECISION_AUDIT_NOT_DISPOSITION`. They are audit evidence about Feed execution, never Reputation Effect dispositions.

The optional `ReputationFeedLoggingBridge` offers a sealed trace to an existing ooRexx Logging v0.5 `LogService`. Feed does not create logging rules, targets, disclosure scopes, retention policies or logging policy releases. A caller-configured logging rule may deliver the exact trace object; with no matching rule, the bridge is a clean no-op. This preserves the ownership boundary: Feed owns *why its domain rule reached an outcome*; ooRexx Logging owns *how/where that audit evidence is delivered*.

## Governed Feed policy deployment topology (v0.11)

v0.11 advances the Institutional Policy integration from global effective-dated handover to Institutional Policy v0.6's **deployment topology and bounded progressive rollout**. `ReputationFeedPolicySet` still owns the meaning of lineage, corroboration, provenance eligibility and geographic-salience rules; deployment changes only which already-reviewed set is permitted to execute for a service/region/channel/tenant/cohort point.

`ReputationFeedInstitutionalPolicyBridge~operativeForContext()` resolves through `InstitutionalPolicyCatalog~executionContextForContext()`. Once topology bindings are effective, the older `operative(catalog,time)` entry point is deliberately routed through the same resolver with a missing point and therefore fails `DEPLOYMENT_POINT_REQUIRED` rather than becoming a topology bypass. Catalogues with no topology remain legacy-global compatible.

`ReputationFeedPolicyDeploymentEvidence` retains the exact deployment point, topology state, immutable deployment binding and—during an authorized overlap—the exact `InstitutionalPolicyProgressiveBinding`. Governed outcomes therefore distinguish `ACTIVE`, `CANARY`, `STAGED`, scoped suspension and not-deployed states without changing the underlying evidence packet.

A bounded progressive rollout can keep ordinary traffic on v1 while a pilot cohort receives v2, then perform cutover or rollback by adding later immutable topology bindings. Historical replay reconstructs the exact route that existed at the event time. If two policy versions remain effective after the authorized overlap expires, resolution fails closed with `PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED`.

The governed Feed -> Reputation Effect bridge copies the exact deployment evidence into every promoted observation anchor: policy identity, policy-set identity, deployment point, mode/source, binding identity/id and progressive-rollout identity/id. Counterfactual executions remain non-promotable.

Example shape:

```text
normal cohort during canary -> v1 / CORROBORATED / ACTIVE
pilot cohort during canary  -> v2 / CORROBORATING / CANARY
cutover                      -> v2 / CORROBORATING / ACTIVE
rollback                     -> v1 / CORROBORATED / ACTIVE
after overlap authorization -> PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED
```

The v0.10 effective-dated operative/counterfactual semantics remain intact underneath this topology layer.

## Structured interaction acquisition boundary (v0.9)

v0.9 adds an optional rich-interaction acquisition path; the current validated closure is `Interaction Event v0.3` and `Structured Utterance v0.3`. The Feed does **not** parse flattened chat text and does not convert model assessments into facts. It consumes structured source-domain objects and produces a sealed `ReputationInteractionEvidencePacket` under a fixed `DEIDENTIFIED_ANALYTIC` privacy boundary.

The source domains remain authoritative for their own semantics:

- Interaction Event owns event identity, element privacy, assessments, correlations and causal-status links. Feed uses `InteractionCaptureLibrary~projectEvent(..., InteractionProjectionPolicy~deidentified)` and retains assessments as assessments. A `CANDIDATE_NOT_PROVEN` relationship stays candidate evidence.
- Structured Utterance owns segment purpose, data role, information lineage, generation intent and information-use analysis. Feed projects each segment independently with `UtteranceProjectionPolicy~deidentified`; it preserves controlled semantic tokens and evidence points while deliberately not copying raw customer lineage references.

The two Feed adapters remain independent by design. The earlier Interaction Event v0.2 compatibility defect is resolved in the current API authority: Interaction Event v0.3 supplies the native evidence classes expected by `StructuredUtteranceInteractionBridge`, and its v0.3 bridge test passes under ooRexx r13196. Feed still does not require that cross-package bridge because independently consuming each source domain keeps representation lineage and assertion ancestry explicit.

Turning a packet into a Feed claim requires a sealed `ReputationInteractionClaimSpec`. The specification must contain an explicit `assertionRootId`. This prevents one underlying conversation from counting twice when it is represented once as a Structured Utterance and once as an Interaction Event. Claim confidence is supplied explicitly by the claim specification; source assessment scores are retained as evidence but do not silently become Feed confidence.

The interaction packet is also a first-class Queue Fabric payload:

```text
reputation/feed/interactions/<source-kind>/<source-id>/<packet-id>
reputation/feed/decisions/<policy-id>/<policy-version>/<trace-id>
```

with authority boundary `PRIVACY_PROJECTED_INTERACTION_EVIDENCE_NOT_DISPOSITION` and independent persistence identity `reputation.feed.interaction-evidence/1`. Rich content items, assessment evidence, candidate relationships, semantic tokens and correlations survive Queue Fabric restart. Alchemy authority/sealer objects are not persisted.

## Queue Fabric durable transport boundary (v0.9; persistence foundation from v0.8)

v0.9 retains the optional `ReputationFeedQueueBridge` introduced in v0.7 and the durable persistence contracts introduced in v0.8. The bridge is deliberately **publish-only**: it does not define topics, queues, subscriptions, ACLs, persistence rules, security domains, or remote peers. Those remain Queue Fabric wiring authority.

The bridge requires a pre-existing topic named `REPUTATION_FEED` whose canonical topic root is exactly `reputation/feed`. Sealed Feed objects are published directly as ooRexx object-graph payloads under deterministic subtopics:

```text
reputation/feed/raw/<source-kind>/<source-id>/<envelope-id>
reputation/feed/claims/<source-id>/<claim-id>
reputation/feed/hypotheses/<event-type>/<hypothesis-id>
reputation/feed/corrections/<type>/<target-claim>/<correction-id>
reputation/feed/alerts/<watchset-id>/<hypothesis-id>
reputation/feed/interactions/<source-kind>/<source-id>/<packet-id>
reputation/feed/decisions/<policy-id>/<policy-version>/<trace-id>
```

Queue headers retain the Feed API, object class/id and an explicit authority boundary such as `RAW_EVIDENCE_ONLY`, `CLAIM_NOT_FACT`, `HYPOTHESIS_NOT_EVENT`, or `WATCH_SIGNAL_NOT_DISPOSITION`. Topic transport therefore cannot silently promote Feed evidence into authoritative Reputation Effect state.

Temporary Queue Fabric delivery retains the exact ooRexx payload object. v0.8 introduced independently-versioned Queue Graph persistence contracts and restore factories for routed raw envelopes, claims, event hypotheses, corrections and watch matches; v0.9 adds the interaction-evidence packet as a sixth durable type; v0.12 adds the governed decision trace as the seventh durable type. Persistent and retained publication therefore preserve rich Feed objects across Queue Fabric restart. Callers must register Feed types on a codec before constructing a recovering `ObjectQueueManager`; `ReputationFeedQueuePersistenceSupport~newCodec()` is the convenience path. Alchemy sealer/authority objects are never serialized into queue journals; caller-owned restore context is supplied to the factory registry.

### Alchemy v0.8 construction

The Feed house base now enters `AlchemyObject` through the preferred non-virtual `INIT` path (`self~init:super(...)`) instead of the compatibility `initAlchemy()` entry point. STANDARD adoption evidence therefore reports base `0.8`, construction entrypoint `INIT`, and no legacy-entrypoint warning for migrated objects.

## Core rule

**Publication count, reach, range, publisher ownership, publication lineage, and assertion ancestry are different signals.**

Thirty regional mastheads may represent thirty distribution surfaces while still providing only one underlying evidential lineage.

## Claim-level assertion ancestry (v0.6)

v0.6 closes the gap between **independent publication** and **independent assertion**. A Reuters article, BBC article, local paper and AI-generated regional rewrite may all be editorially distinct publication surfaces while repeating one Boeing press-release assertion. Treating those mastheads as four corroborating sources would overstate the evidence.

`ReputationAssertionOriginLink` records a retained ancestry relation for one atomic Feed claim:

- `rootAssertionId` — stable Librarian/lineage identity for the underlying assertion family;
- `sourceId` — source participating in that ancestry;
- `relationship` — for example `DERIVED_FROM`, `QUOTED_ASSERTION`, `AI_REWRITE_OF`, or `PRIMARY_CONFIRMATION`;
- `evidenceId` and detail — evidence supporting the lineage judgement.

An atomic `ReputationFeedClaim` may carry several ancestry links, but all must resolve to the **same** root assertion. A claim attempting to carry two different assertion roots is a modelling error: Librarian should split it into two claims instead of flattening two independently sourced assertions into one record.

When ancestry is resolved, `claim~corroborationFamilyId` is `ASSERTION:<rootAssertionId>`. When ancestry is not known, v0.6 preserves backward compatibility by falling back explicitly to `PUBLICATION:<familyId>` (or `CLAIM:<claimId>` when even publication lineage is absent). The fallback is visible in `ReputationCorroborationAssessment`; no assertion ancestry is invented.

For example:

```text
Reuters     publication family R  --\
BBC         publication family B  ---+--> ASSERTION:BOEING-PR-123
Local AI    publication family L  --/

FAA notice  publication family F  ----> ASSERTION:FAA-CONFIRM-987

publication families = 4
assertion families   = 2
```

The same rule applies to contradiction. Two newspapers repeating one denial remain one denial assertion family; a genuinely independent regulator denial creates the second contest family.

`ReputationLibrarianFinding` now carries assertion-origin links directly. `ReputationLibrarianClaimBridge` copies those rich objects into the sealed claim; the adapter layer does not infer them from publisher names or ownership metadata.

The hypothesis→Effect bridge also groups representatives by the effective assertion family. Once a hypothesis is corroborated, three publication rewrites of one primary assertion therefore produce **one** `ReputationObservation`, not three. Effect evidence anchors retain publication family, assertion-root family, ancestry-resolution state, and the effective corroboration family separately.




## Provenance-aware corroboration (v0.5)

v0.5 makes source-authentication and source-history evidence part of the deterministic corroboration cut **without converting either into a source trust score**. `ReputationCorroborationEvidencePolicy` decides which provenance classes are eligible to count as corroborating families. The default is deliberately conservative only where the evidence is actively adverse: failed authentication and an attached compromised-source history state remain visible but become `DISCOVERY_ONLY`; unverified and legacy/unassessed origin remain eligible but are explicitly labelled.

Each active claim receives a `ReputationCorroborationEvidenceStatus` containing its lineage family, authentication state, compromise state, evidence identifiers, eligibility disposition and deterministic reason. `ReputationCorroborationAssessment` therefore carries both the complete evidence population and the subset actually admitted to the corroboration threshold. Confidence is still the Librarian/content confidence of eligible lineage-family representatives; provenance does not add or subtract points.

The default policy behaves as follows:

```text
VERIFIED origin            -> ELIGIBLE
UNVERIFIED origin          -> ELIGIBLE, marked UNVERIFIED_ALLOWED_BY_POLICY
UNASSESSED legacy origin   -> ELIGIBLE, marked UNASSESSED_ALLOWED_BY_POLICY
FAILED authentication      -> DISCOVERY_ONLY
source compromised         -> DISCOVERY_ONLY
```

A caller can explicitly use a more permissive or stricter evidence policy. Policy overrides are retained as reason codes such as `FAILED_AUTH_ALLOWED_BY_POLICY`; they are never silent. A failed-authentication denial therefore cannot manufacture `CONTESTED` state under the default policy.

The hypothesis-to-Effect bridge now uses the same provenance assessment when selecting representative families. A failed or compromised family cannot hitch a ride into `ReputationObservation` merely because two clean families already made the hypothesis corroborated. The Effect evidence anchor retains source-authentication state/evidence and source-history/compromise metadata.

## Source authentication and source history (v0.4)

v0.4 separates **origin authentication** from **assertion truth**.  A verified
source proof means that the retained envelope matches a declared source/key/
endpoint binding; it does not increase the Librarian's content confidence and
it does not make the source's claims true.

The source-authentication surface contains:

- `ReputationSourceKeyBinding` — time-bounded source/key/endpoint/locator
  binding.  Ed25519 public keys may be retained directly; SipHash-128 uses a
  caller-owned `CryptoMacKeyRing`, so Feed never acquires ambient secret-key
  authority.
- `ReputationSourceAuthProof` — detached proof bound to source id, binding id,
  envelope id, endpoint, key id, signed time, payload digest and locator.
- `ReputationSourceAuthenticator` — deterministic verification returning
  `VERIFIED`, `UNVERIFIED`, or `FAILED` plus a reason code.  It deliberately
  exposes no trust/reputation score for the source.
- `ReputationSourceHistoryLedger` / `ReputationSourceHistoryView` — append-only
  authentication, key-rotation, endpoint-change, correction, retraction,
  compromise and restoration evidence with deterministic as-of replay.
- `ReputationSourceEvidencePacket` — keeps the sealed raw envelope,
  authentication result and optional source-history view together as rich
  provenance rather than flattening them into a Boolean.

`ReputationLibrarianClaimBridge~claimFromFinding()` accepts an optional source
evidence packet.  The resulting claim retains `sourceAuthenticationState` and
`sourceAuthenticationEvidenceId`; its Librarian `confidence` is intentionally
unchanged.  Downstream policy may inspect those independent evidence axes, but
Feed does not silently weight content because a source authenticated (or failed
to authenticate).

The normal acceptance suite uses SipHash-128 source proofs because pure-ooRexx
Ed25519 verification is intentionally CPU-heavy.  Ed25519 remains a supported
external-proof algorithm through `oorexx_crypto_v0.1`; its cryptographic
primitive is validated by the crypto package rather than making every Feed
regression pay public-key arithmetic cost.

## Acquisition adapters (v0.3)

v0.3 adds the source boundary that sits *before* Librarian lineage and claim extraction. It is deliberately transport/provider-neutral: network clients may fetch RSS, JSON, XML, AT-Protocol records, regulator notices, or other material, but they must hand Feed a sealed `ReputationRawEnvelope`.

The acquisition model separates:

- `ReputationSourceIdentity` — stable source class, publisher/ownership metadata, default geography, endpoint and descriptive evidential role;
- `ReputationRawEnvelope` — source identity, receive/source timestamps, content type, locator, payload digest, retained raw segments and source fields;
- `ReputationAcquiredDocument` — normalized retained document without semantic event judgement;
- `ReputationLibrarianHandoff` — paragraph-by-paragraph material plus one or more named custom corpora;
- `ReputationLibrarianFinding` — explicit provider output carrying paragraph evidence, event type/key, subjects/concepts, geography, stance and confidence;
- `ReputationLibrarianClaimBridge` — deterministic conversion of a sealed finding into a sealed `ReputationFeedClaim` with the original document/source provenance retained.

Three materially different concrete adapters are supplied:

- `ReputationNewsPublicationAdapter` — creates a publication-lineage article and surface, but **does not invent reach or range**;
- `ReputationOfficialNoticeAdapter` — retains an official/regulator notice for Librarian analysis, but does **not** treat the source label as automatic truth or a publication vote;
- `ReputationPublicStreamAdapter` — retains social/public-stream material as discovery input without turning a post into an authoritative claim.

`ReputationAcquisitionRouter` selects an adapter by explicit source class. Unsupported source kinds return `NO_ADAPTER`; they are not silently coerced into a news/article shape.

Source `evidentialRole`, publisher group and ownership group are descriptive metadata only. They are never converted into a trust score or an independent-lineage count by the adapter layer. A sealed `ReputationSourceIdentity` proves only the integrity of the object inside this runtime; authentication that a remote endpoint really is the claimed regulator/publisher belongs to the transport/source-registry boundary and must be retained as separate evidence.

The end-to-end boundary is therefore:

```text
transport client
    -> ReputationRawEnvelope
    -> source-class adapter
    -> AcquiredDocument + LibrarianHandoff
    -> Librarian/custom corpus
    -> LibrarianFinding
    -> FeedClaim
    -> lineage-normalised hypothesis/corroboration
    -> ReputationObservation
    -> Reputation Effect
```

## Librarian cut

The feed does not contain an LLM or a general semantic model. A Librarian/content-analysis layer supplies retained paragraph-level comparisons against a named custom corpus.

`ReputationParagraphComparison` records:

- lexical similarity;
- semantic similarity;
- claim overlap;
- entity overlap;
- numeric-fact overlap;
- temporal-fact overlap;
- paragraph-role similarity;
- confidence;
- the corpus identity used for the comparison.

`ReputationArticleComparison` adds sequence alignment and rare-fact overlap. `ReputationLineagePolicy` then applies a deterministic cut (default article score 78 with at least two aligned paragraphs).

This explicitly supports the case **“same article, different words”**: low lexical overlap can still group when claim/fact/entity/sequence evidence shows common descent.

## Reach and range

`ReputationReachEvidence` requires an audience estimate, source identity, measurement time, confidence and optional expiry. Invalid/missing reach does not become zero or silently become “known”.

`ReputationRangeEvidence` carries an evidenced geography set with source and confidence.

`ReputationReachRangeSummary` exposes:

- `publicationSurfaceCount`
- `lineageFamilyCount`
- `validatedReachSurfaceCount`
- `grossValidatedReach`
- `reachComplete`
- `rangeComplete`
- `rangeGeographies`

`grossValidatedReach` is intentionally named **gross**: the package does not pretend it can deduplicate overlapping audiences without further evidence.

## Lineage grouping

`ReputationLineageEngine` treats accepted pairwise comparisons as edges and creates deterministic connected lineage families. Thus A≈B and B≈C can form one family even if A and C were never directly compared.

Publisher group metadata is retained but is not authoritative for lineage. Two titles in one group can be independent; two titles in different groups can still derive from the same wire copy or press release.

## Effect boundary

Optional `integration/ReputationFeedEffectBridge.cls` promotes retained article/claim/hypothesis evidence into `ReputationObservation` objects with lineage metadata. It deliberately does **not** create `ReputationEvent`, geographic effects, or a reputation decision.

That preserves the boundary:

```text
transport material
        |
        v
raw envelope + source-class adapter
        |
        v
Librarian paragraph/corpus analysis
        |
        v
Feed lineage + normalized claims
        |
        v
corroborated event hypothesis
        |
        v
ReputationObservation
        |
        v
Reputation Effect
```

## Running

Validated with the Architect-supplied ooRexx 5.3.0 r13196 debug build.

```sh
export OOREXX_REXX=/path/to/rexx
export ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8
export OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.14
export REPUTATION_EFFECT_ROOT=/path/to/reputation_effect_v0.2
export QUEUE_FABRIC_ROOT=/path/to/oorexx_queue_fabric_v0.9-dev4
export INSTITUTIONAL_POLICY_ROOT=/path/to/institutional_policy_v0.6
export INTERACTION_EVENT_ROOT=/path/to/interaction_event_v0.3
export STRUCTURED_UTTERANCE_ROOT=/path/to/structured_utterance_v0.3
./run_tests.sh
```

`ALCHEMY_OBJECTS_ROOT` and `OOREXX_CRYPTO_ROOT` are required. Runtime Registry, Reputation Effect, Queue Fabric, Institutional Policy, Interaction Event, and Structured Utterance roots are optional; each corresponding integration test is skipped when its root is absent.

## Current release provenance

v0.11 is built directly from the exact `reputation_feed_v0.10.zip` present in the Architect-supplied `oorexxapis(20260824-191304).zip`.

- predecessor Feed v0.10 SHA-256 `3ccc368854feb4df477163bc6be3073da40490bd31bea97533d02803b7cd7e76`
- current API roll-up SHA-256 `c2e3b1e7751e3ed69514cc2743e1ba82c0d3e6b7ca2b16f999a862f3dcfef5a8`
- Alchemy Objects v0.8 SHA-256 `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073`
- ooRexx Crypto v0.1 SHA-256 `3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`
- Institutional Policy v0.6 SHA-256 `179682880c0f7d221114bfc648fab4e9f678153640d850ed1c3944c478eb6ae3`
- Queue Fabric v0.9-dev4 SHA-256 `9c1487f8dc878ae21a19e8fc8a139c801a80a97acd2c6575635003e6f8069898`
- Runtime Registry v0.14 SHA-256 `b8748634f271f5389b9e7e4fd7089eda314b0eea90ab6e47151ae1de270c6209`
- Reputation Effect v0.2 SHA-256 `f3778c9114b97ec25fbd146d640db9ad25ee72dec8b5e6c6cdebf06261957b63`
- Interaction Event v0.3 SHA-256 `0d2f46ddc5617ab0879bf06fd373dc6ea8cebbd5aeb5b36e2ef86d52f471b536`
- Structured Utterance v0.3 SHA-256 `76f56332e21dc8614c07b64358dcabf0cc6ae06f0eff4aeaa9a8a18a0b727974`
- ooRexx r13196 DEB SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

## Event hypotheses and corroboration (v0.2)

Feed v0.2 adds a deterministic bridge from normalized acquisition claims to evidence-bearing event hypotheses. It still does **not** create authoritative Reputation Effect events.

A `ReputationFeedClaim` retains its article/source lineage family, event type and optional normalized event key, assertion/denial stance, confidence, source citation, subjects/concepts, observation geography, and affected geography.

`ReputationEventClusterEngine` groups compatible claims. `ReputationCorroborationAssessment` then makes the threshold packet explicit: total claim count, independent assertion/denial family counts, required family count, family-normalised confidence, required confidence, `CORROBORATING`/`CORROBORATED`/`CONTESTED` status, and threshold result.

Corroboration is deliberately lineage-normalised. Ten or ten thousand AI rewrites of one story may affect distribution reach/range, but still contribute only one independent evidence family.

Corrections are append-only evidence via `ReputationFeedCorrection` and `ReputationHypothesisLedger`; historical replay before and after a retraction is deterministic.

Watchsets and geographic-salience evidence make active business scope explicit without embedding a reputation judgement into the acquisition layer.
