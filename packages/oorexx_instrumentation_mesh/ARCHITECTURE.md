# Instrumentation Mesh architecture — v0.1-dev8

## Authority model

```text
service / fabric authority
       |
       | snapshot(s)
       v
Instrumentation Mesh publisher
       |
       | atomic authenticated publication
       v
collector + bounded history + publication evidence
       |
       +--> Keynote / Wire3D read projection
       +--> Instrumentation Intentions
       +--> usage/freshness analysis
```

The arrows carry evidence, not authority.  Deployment geography, service
membership, architecture relationships, time authority and operational mutation
remain separate concerns.

## Identity

Stable identity is estate + service + instance + node, represented by
`instrumentation://...`.  `mi_id`, service kind and location are attributes,
not substitutes for identity.  IP addresses and render coordinates are never
promoted to identity.

## Metrics

A sample has name, kind, unit, value, observation interval/time and dimensions.
Counters are always dimensional series.  `gaugeSet()` retains current
latest-value semantics for producer compatibility.  `gaugeSeriesSet()` is the
explicit non-lossy API for simultaneously meaningful dimensional gauges.

## Publication freshness

`InstrumentationPublisher~publish(observedAt,publishedPosixSeconds)` optionally
carries a qualified POSIX-second publication instant.  The collector stores the
publisher id, publication id, sequence, display timestamp and numeric instant
alongside each accepted latest service snapshot.

Freshness is calculated later by a read-side assessor using a caller-supplied
current POSIX instant and policy windows.  No timezone parsing occurs in the
Mesh.  Future-dated evidence is `UNKNOWN`, not silently clamped.

Freshness and service health are orthogonal:

```text
source health = HEALTHY, publication freshness = STALE
```

means "the last source report said healthy, but observation has gone stale".
It does not mean either HEALTHY-now or FAILED-now.

## Current-time seam

Single Time Service v0.4 represents absolute instants as integer POSIX seconds
(`TimeInstant~ticks`).  A caller may pass those ticks directly to the freshness
assessor.  Instrumentation Mesh deliberately does not own a system clock and
does not become dependent on timezone rules.

## Dynamic NOC discovery

Collectors already support identity selectors.  A projection can therefore ask
for all current observations at one node/MI and render newly appearing services
without hard-coded service types.  The deployment catalogue may additionally
name expected semantic refs.  Missing expected refs remain visible as missing
observation rather than being dropped.

## Topology boundary

Operational instrumentation does not invent a second relationship graph.
Project architecture interactions, RexxOS membership, Management relationships
and deployment links remain authoritative where they are defined.  Consumers
may join those relationships to `semantic_ref` observations.

## Privacy

Instrumentation must contain operational facts, not protocol payloads,
credentials or user content.  SMTP and IMAP adapters consume bounded semantic
events/names and byte counts.  Mailbox names, usernames, message content,
addresses, SEARCH expressions, tokens and provider capabilities are excluded.


## Relationship observation boundary

`instrumentation.relationship/1` is an observation of a domain-owned edge, not
a new graph authority.  Endpoints are semantic references.  `kind` and
`authority` retain the source domain's meaning; Instrumentation does not infer
relationships from co-location, matching names, traffic counters or geography.

`instrumentation.relationship-set/1` groups edges under an explicit `scope_id`
and authority.  `complete=true` means the set is the complete current projection
for that exact scope.  The collector replaces the current set atomically while
retaining bounded earlier sets.  An absent edge in a newer complete set is
therefore no longer current, but the Mesh does not manufacture a `WITHDRAWN`
event that the source never asserted.

This distinction matters across the estate:

- RexxOS Grid owns MU/MI membership only; it does not become ACTIVE/SPARE or
  placement authority.
- Queue Fabric owns configured channel/routing facts; traffic relationships do
  not imply application dependency.
- Identity peer epoch authority can state the currently fenced holder without
  claiming responsibility for promotion policy.
- Management Relationship Discovery may project richer domain relations only
  through explicit semantic endpoint resolution and preserves relation authority.

Keynote/Wire3D may join these observations with separately authoritative
deployment geography and static architecture links.  Presentation does not
merge their authorities.

## dev7 operational event timeline

Events are occurrence evidence, not current state. `instrumentation.event/1`
therefore sits beside snapshots and relationship sets rather than replacing
either. A source event states that the named source authority observed the
occurrence. A collector-derived event states only that accepted observations
changed. Derived entries are always marked `derived=true` and name
`INSTRUMENTATION_OBSERVER` as their event authority while retaining the source
authority in evidence.

Publishers may resend their bounded retained event journal after a lost receipt.
The collector fences publication sequence as before and additionally deduplicates
events by `authority + event_id`, so successful later publication cannot create
duplicate timeline entries.

Complete relationship-set comparison may produce visibility-change observations.
`RELATIONSHIP_CEASED_VISIBLE` means the edge is absent from the newer complete
observed scope; it does not assert deletion, failover, disconnection or any other
source-domain mutation. Likewise `HEALTH_CHANGED` describes the difference
between accepted health observations and never grants restart/remediation
authority.

Bounded histories retain contiguous Array tails. This is deliberate: ooRexx
Array indexes are sparse and `remove(1)` does not shift later items down.
## 8. Explicit operational correlation

Correlation is a read-side projection over retained `instrumentation.event/1`
records.  `InstrumentationCorrelationView` groups **only** events carrying the
same non-empty producer-supplied `correlation_id`.  It never groups by
observation time, host, MI, service kind, severity, geography or relationship
proximity.

The correlation projection uses schema `instrumentation.correlation/1` and
records `basis=EXPLICIT_CORRELATION_ID` plus
`ordering=COLLECTOR_ACCEPTANCE_ORDER`.  Source `observed_at` values remain
evidence fields, not a cross-machine ordering authority.

Optional `causation_id` is an opaque source-declared cause reference.  The view
marks whether that reference resolves to an event retained in the same group,
but does not infer missing causal edges.  `context_refs` carry explicit semantic
context such as a change, incident, acceptance run, deployment or service
reference without granting Instrumentation authority over that object.

A correlation may therefore contain events from several authorities.  The view
retains every contributing authority and labels itself
`READ_ONLY_CORRELATION_VIEW`.  An incident/change system may consume or supply
these references, but only that system can create/close the incident or change.

The generic `InstrumentationEventObserver` exists for authorities that already
know an occurrence but do not otherwise expose an Instrumentation snapshot.
It is event-only and creates no new lifecycle authority.

