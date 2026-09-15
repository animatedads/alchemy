# Reputation Feed v0.12 architecture

## v0.12 governed decision-audit boundary

`ReputationFeedDecisionTrace` is the bounded audit projection of a `ReputationFeedGovernedOutcome`. It records policy/deployment identity, deterministic outcome status and threshold/count facts, plus reason-code counts. Raw claims and customer/source payloads are intentionally absent.

The trace is a Feed domain object and therefore may be carried directly through Queue Fabric. Its persistence type is `reputation.feed.decision-trace/1`, independent of the package API. Queue publication uses `reputation/feed/decisions/...` and the boundary `GOVERNED_DECISION_AUDIT_NOT_DISPOSITION`.

`ReputationFeedLoggingBridge` is optional glue to ooRexx Logging v0.5. It passes the sealed trace as the exact `LogEvent~payload`; it does not own `LogRule`, `LogScope`, target, retention or logging-policy semantics. No matching logging rule means no event.

## v0.11 institutional policy deployment topology

`ReputationFeedPolicySet` remains the domain-owned deterministic rule bundle. Institutional Policy v0.6 owns publication authority, global lifecycle, scoped deployment topology and bounded progressive overlap; it does not interpret Feed lineage/provenance/salience semantics.

```text
InstitutionalPolicyRelease<ReputationFeedPolicySet>
        |
        +-- publication / authority evidence
        +-- global lifecycle evidence
        +-- immutable deployment bindings
        +-- optional bounded progressive overlap
                         |
                         v
        InstitutionalPolicyExecutionContext
                         +
        ReputationFeedPolicyDeploymentEvidence
                         |
                         v
        ReputationFeedPolicyExecution
                         |
                         v
        ReputationFeedGovernedOutcome
```

Topology resolution is fail-closed. Once an effective topology binding exists, `operative(catalog,time)` cannot bypass it; the missing deployment point surfaces as `DEPLOYMENT_POINT_REQUIRED`. `operativeForContext()` uses the full service/region/channel/tenant/cohort point and retains the exact selected binding. `STAGED`, scoped suspension and not-deployed states do not execute the Feed rule set.

Progressive rollout authorizes only a **bounded overlap between two exact reviewed versions**. Routing still comes from ordinary immutable topology bindings. A canary can therefore put one cohort on v2 while ordinary traffic remains on v1, followed by cutover or rollback through later bindings. If both releases remain effective after the authorization window, resolution fails `PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED`. Historical replay uses binding effective times, so later cutover/rollback cannot rewrite earlier routing.

Feed -> Effect promotion remains stricter than evaluation: only `OPERATIVE + CORROBORATED` crosses the boundary. Observation anchors retain policy/release identity plus deployment point, mode/source, binding identity and progressive-rollout identity. Counterfactual execution remains replay/comparison evidence only.

## v0.9 structured interaction boundary

Reputation Feed may acquire evidence from conversational domains, but it does not become the conversation model. The integration topology is:

```text
StructuredUtterance -----> deidentified segment projection --\
                                                       +--> ReputationInteractionEvidencePacket
InteractionCaptureLibrary -> deidentified event projection --/              |
                                                                             v
                                                              explicit InteractionClaimSpec
                                                                             |
                                                                             v
                                                                  ReputationFeedClaim
```

`ReputationInteractionEvidencePacket` is a Feed-owned evidence envelope containing rich projected content items, source assessments, candidate event relationships, semantic tokens, correlations and stable source-domain evidence points. It accepts only `DEIDENTIFIED_ANALYTIC`. Raw customer-specific source wording remains in the source domain.

The packet is **not a claim**. `ReputationFeedInteractionClaimBridge` requires a separate sealed claim specification containing event type, confidence, subjects/concepts/geographies and—critically—an explicit underlying assertion root. This lets two representations of the same interaction share one `ASSERTION:<root>` while genuinely different interactions can form independent evidence families.

Source assessment confidence and Feed claim confidence are separate. An Interaction Event style assessment of `SASS=91` remains assessment evidence; the bridge never turns 91 into a Feed claim score. Likewise source causal status such as `CANDIDATE_NOT_PROVEN` remains explicit relationship evidence and is not upgraded.

The Feed adapters remain independent. In the current API closure, Interaction Event v0.3 supplies the native evidence objects expected by Structured Utterance v0.3 and the adjacent bridge test is green under r13196. Feed still consumes each source domain independently so duplicate object-model representations cannot self-corroborate.

Interaction packets route under `reputation/feed/interactions/...` and persist as `reputation.feed.interaction-evidence/1`. The persistence schema is independent of Feed release identity and restores nested Feed evidence objects rather than flattening them.

## v0.8 Queue Fabric persistence boundary

Queue Fabric is an optional transport/persistence substrate, not a Reputation Feed authority. `ReputationFeedQueueBridge` publishes already-formed Feed objects to a pre-existing `reputation/feed` topic namespace. Queue wiring remains external and the payload remains an ooRexx object graph. Persistent/retained delivery is rejected until an explicit Feed restore contract exists; canonical-string flattening is not an acceptable persistence substitute.

The transport layers therefore remain:

```text
source adapter -> Feed object -> Queue topic/queue -> Feed consumer
                    |                 |
                    |                 +-- routing/delivery authority only
                    +-- evidence semantics remain Feed-owned
```

## House foundation boundary

`ReputationFeedAlchemyObject` subclasses `AlchemyObject` v0.8. Feed objects inherit the common identity/lifecycle/telemetry/evidence surface while lineage, reach, range and Librarian scoring remain Feed-owned semantics. The optional final `ReputationFeedAlchemyContext` supplies caller-owned sealing/capability services without ambient package authority.

## Domain boundary

Reputation Feed owns acquisition evidence and lineage. It does not own reputation semantics.

The fundamental distinction is:

```text
PUBLICATION SURFACES != REACH != RANGE != SOURCE LINEAGE
```

A publisher can A/B-test or AI-rewrite one story across many titles. Those variants can increase distribution range and exposure without increasing independent corroboration.




## v0.6 assertion-ancestry boundary

Publication lineage and assertion lineage are deliberately different graphs.

```text
Publication graph:
  Reuters article     -> PUB-R
  BBC article         -> PUB-B
  Local AI variant    -> PUB-L

Assertion graph:
  PUB-R --\
  PUB-B ---+--> BOEING-PR-123
  PUB-L --/
  FAA notice -------> FAA-CONFIRM-987
```

`ReputationFeedClaim~familyId` remains the article/publication lineage family. `ReputationAssertionOriginLink` carries claim-level ancestry evidence and `assertionOriginFamilyId` identifies the common root assertion when Librarian can resolve it. Corroboration uses `corroborationFamilyId`: explicit assertion root first, publication lineage as visible fallback, claim identity only as final fallback.

One claim represents one atomic assertion root. Multiple ancestry links may describe the path to that root, but links with conflicting roots are rejected rather than flattening independently sourced assertions into one claim.

This graph is orthogonal to source authentication. `VERIFIED Reuters` means the retained Reuters envelope really came through the bound Reuters source path; it does not mean Reuters originated the assertion. Conversely, a claim may correctly resolve to a Boeing assertion root even when its immediate publication origin is merely `UNASSESSED`. Authentication eligibility and assertion independence are therefore applied as separate axes before a family can corroborate.

The Effect bridge uses the same effective family key used by corroboration, preventing duplicated publication descendants from reappearing as multiple downstream observations after a hypothesis has passed its threshold.

## v0.5 provenance-aware corroboration boundary

Authentication and source history now constrain **evidential eligibility**, not content confidence:

```text
retained claim
   + origin-authentication state
   + attached source-history compromise state
        |
        v
CorroborationEvidenceStatus
   ELIGIBLE | DISCOVERY_ONLY
        |
        v
lineage-family threshold
```

All active claims remain in the hypothesis and assessment. The provenance cut only decides whether a claim's independent lineage family can participate in assertion/denial thresholds. This keeps discovery evidence inspectable and replayable while preventing known-bad origin evidence from masquerading as independent corroboration.

The eligibility rule is categorical and evidence-bearing, not scalar. There is no `sourceTrustScore`, `reliabilityWeight`, or hidden confidence multiplier. The Librarian confidence remains unchanged. `ReputationCorroborationEvidencePolicy` is the explicit policy surface for admitting or excluding provenance classes.

A lineage family that contains both eligible and discovery-only variants is counted once as eligible, never simultaneously as an independent discovery-only family. The Effect bridge selects representatives only from the eligible family set determined by the same assessment.

## v0.4 authenticated-origin boundary

Source authentication is a provenance lane, not a truth lane:

```text
RawEnvelope
   + SourceKeyBinding
   + detached SourceAuthProof
        |
        v
SourceAuthenticationResult  ----->  SourceHistoryLedger/as-of view
        |                                  |
        +---------------+------------------+
                        v
                SourceEvidencePacket
                        |
                        v
                 Librarian/claim bridge
```

The proof binds source id, binding id, envelope id, endpoint, algorithm/key id,
signed time, payload digest and locator.  Endpoint and locator-prefix checks are
performed independently of cryptographic verification.  A cryptographically
valid proof presented through an unbound mirror therefore remains an origin
binding failure.

Source-history events are immutable facts such as `AUTHENTICATION`,
`KEY_ROTATED`, `ENDPOINT_CHANGED`, `CORRECTION`, `RETRACTION`,
`COMPROMISE_DECLARED`, and `SOURCE_RESTORED`.  Views expose counts and current
states as-of a requested time; there is deliberately no `reliabilityScore()` or
universal source ranking.

Claims retain authentication state/evidence independently of content confidence.
This keeps provenance usable by later policy without turning cryptographic
identity into editorial authority.

## v0.3 acquisition boundary

The source boundary now precedes the existing article-lineage/event-hypothesis layers:

```text
source identity + raw transport envelope
        -> source-class adapter
        -> retained document
        -> paragraph/corpus Librarian handoff
        -> explicit Librarian finding
        -> Feed claim
```

Adapters are intentionally weak. They may normalize shape and retain provenance, but they cannot infer reputation direction, create `ReputationEvent`, assign source trust, count themselves as independent corroboration, or fabricate reach/range evidence. Sealing a source identity protects in-process object integrity; it does not authenticate the remote publisher/regulator endpoint. External source authentication remains distinct evidence.

`ReputationSourceIdentity` keeps publisher group and ownership group because those facts can help Librarian/lineage analysis, but neither field is a lineage decision. `evidentialRole` is likewise descriptive (`DISCOVERY`, `EDITORIAL_REPORTING`, `OFFICIAL_NOTICE`, etc.), not a confidence multiplier.

`ReputationRawEnvelope` distinguishes `receivedAt` from the source's own observed/publication time and retains the original locator and caller-supplied payload digest. Content is held as ordered role-bearing segments so an HTML/XML/JSON transport parser does not have to flatten headline, standfirst, quote and body structure into one string.

The concrete adapters cover news publications, official/regulator notices and public/social streams. News material may create a `ReputationFeedArticle` for the existing lineage machinery; official notices and public posts do not masquerade as newspaper articles merely to reuse that API.

Every acquisition child created by a context-bearing adapter receives the same caller-supplied `ReputationFeedAlchemyContext`, preserving the house sealing/capability evidence chain across source -> envelope -> normalized document -> Librarian handoff -> claim.

## Article model

`ReputationFeedArticle` retains source/publisher identity and one or more `ReputationPublicationSurface` objects.

Each surface can carry independently validated reach and range evidence. Missing evidence remains missing.

## Librarian interface

The v0.3 boundary hands normalized retained paragraphs to a Librarian or equivalent analyser, which scores comparisons/extractions against named custom corpora.

The Feed receives those scores; it does not invent them.

Paragraph evidence is intentionally multi-axis because AI rewriting can defeat simple hashes and lexical similarity:

```text
lexical       low
semantic      high
claim overlap high
entity order  high
rare facts    high
sequence      high
=> probable common lineage
```

## Article-level lineage

Paragraph scores are combined with article-level sequence alignment and rare-fact overlap. The policy cut is deterministic and versionable.

Accepted pairwise links form a graph. Connected components are lineage families.

A lineage family represents **probable common descent**, not a statement that every publisher, journalist, or outlet is organisationally the same source.

## Reach/range validity

Reach evidence is only counted when its provenance is present and it is valid at the requested time. Range is built as a union only from valid range evidence.

The summary deliberately does not infer audience uniqueness or convert geographic range into reach.

## Promotion boundary

The optional bridge constructs `ReputationObservation` only. Corroboration rules remain downstream; no feed adapter is allowed to declare a `ReputationEvent` authoritative merely because many variants were published.

## Runtime lifecycle

`ReputationFeedRuntimeModule` publishes as module kind `REPUTATION_FEED`, API `reputation.feed/0.12`, through Runtime Registry v0.14.

## v0.2 event-hypothesis layer

The Feed now has a second deterministic stage after article lineage:

```text
articles + Librarian paragraph evidence
        -> lineage families
        -> normalized claims
        -> event-hypothesis clustering
        -> corroboration assessment
        -> watch/geographic-salience evidence
        -> optional lineage-normalised ReputationObservation promotion
```

A hypothesis is not a `ReputationEvent`. It is an acquisition-side statement that a set of retained claims probably refer to the same occurrence.

### Corroboration thresholds are evidence

`ReputationCorroborationAssessment` carries both observed and required figures. A consumer can therefore reason from a packet such as:

```text
claims                     3
independent assertion families 2
required families          2
family-normalised confidence 86
required confidence        70
status                      CORROBORATED
```

Thirty AI rewrites from one lineage remain one independent family. Contradictory independent claims are represented as `CONTESTED`, not silently averaged into a confidence score.

### Normalized event key

A Librarian/source-normalizer may provide an optional stable `eventKey`. When both claims have non-empty keys and the keys differ, the cluster engine will not merge them even if event type, manufacturer, concepts and time are otherwise similar. This prevents adjacent same-sector incidents from collapsing into one hypothesis.

### Corrections and replay

`ReputationHypothesisLedger` retains claims and correction objects. `activeClaimsAt(time)` and `clusterAt(time)` reconstruct the acquisition state as it existed at that moment. Retraction/correction/supersession therefore changes current evidence without rewriting historical knowledge.

### Watchsets

`ReputationWatchSet` is business-context acquisition scope, not a reputation decision. It can describe active event types, subjects, concepts and affected geographies for an airline route/campaign/product surface. `ReputationWatchEngine` reports deterministic overlap evidence only.

### Geographic salience

`ReputationGeographicSalienceEvidence` keeps independent family count, publication surface count, local family count, publication velocity, official attention and confidence separate. `ReputationGeographicSaliencePolicy` reports threshold-backed LOW/MEDIUM/HIGH salience. It never assigns favourable/adverse direction.

### Promotion boundary

`ReputationFeedEffectBridge~observationsFromHypothesis()` defaults to corroborated-only promotion and selects one highest-confidence assertion per independent family. It still creates only `ReputationObservation` objects. It has no authority to construct `ReputationEvent`, geographic effect, or disposition.


## Queue persistence contract

Feed v0.9 defines six independent persistence identities: `reputation.feed.raw-envelope/1`, `reputation.feed.claim/1`, `reputation.feed.event-hypothesis/1`, `reputation.feed.correction/1`, `reputation.feed.watch-match/1`, and `reputation.feed.interaction-evidence/1`. These identities do not track the Feed package version. The queue graph codec receives explicit factories before recovery. Persistence state is a projection boundary: dates and nested value rows are encoded into queue-safe tables/arrays, then restored to rich Feed objects; no internal runtime authority, sealer, telemetry object, or Queue Fabric administrator reference is persisted.
