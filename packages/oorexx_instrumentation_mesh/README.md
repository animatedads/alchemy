# ooRexx Instrumentation Mesh v0.1-dev8

dev8 adds a read-only **operational correlation view** over the dev7 event
timeline.  Correlation is deliberately evidence organisation, not incident,
change, deployment or remediation authority.  Events are joined only when a
producer supplies the same explicit `correlation_id`; timestamp proximity,
co-location, common service kind and severity never create a group.

`instrumentation.event/1` remains the event schema.  dev8 adds optional
`causation_id` and `context_refs` fields while accepting dev7 events that do not
contain them.  `InstrumentationCorrelationView` projects
`instrumentation.correlation/1` groups in collector acceptance order, retaining
source authorities, subjects, related/context references, source-vs-derived
counts, worst display severity and producer-declared causation links.

`InstrumentationEventObserver` is the generic event-only adapter for existing
incident/change/acceptance/application authorities.  `InstrumentationOperationObserver`
can now carry explicit correlation, causation and context references on its
STARTED/COMPLETED/FAILED/CANCELLED source events without changing the existing
progress API.

This follows the estate logging/correlation rule already used by MVS Alchemy:
join distributed evidence with explicit run/test/transaction/correlation
identifiers, not wall-clock coincidence.  Logging remains its own structured
evidence framework; Instrumentation does not replace it.

---

# ooRexx Instrumentation Mesh v0.1-dev7

dev7 adds a replay-safe operational event timeline above the existing snapshot,
relationship, history and management surfaces. Source events retain their named
authority; collector-derived change events are explicitly labelled
`derived=true` and use `INSTRUMENTATION_OBSERVER` authority so a change in
observed evidence is never confused with the underlying service action.

The first concrete source-event producer is `InstrumentationOperationObserver`,
which publishes bounded STARTED/COMPLETED/FAILED/CANCELLED events alongside its
existing progress snapshots. The collector also derives health-change and
complete-relationship-scope visibility-change observations for replay in
Keynote/3D NOC. Publication replay remains idempotent by event identity.

This increment also repairs bounded Array history maintenance throughout the
Mesh. ooRexx Array `remove(1)` does not compact later indexes; dev7 rebuilds a
contiguous retained tail instead of relying on shifting semantics.

Current Storage Fabric Instrumentation Mesh dev3 is qualified through the same
event path without granting Instrumentation Storage authority.

---

# ooRexx Instrumentation Mesh v0.1-dev6

`instrumentation.mesh/0.1` is the common operational observation language for
the ooRexx estate.  Services remain authoritative for their own state; the Mesh
provides semantic identity, metrics, progress, publication, bounded history,
query and separately-authorised management envelopes.  Queue Fabric / QueueRexx
is the preferred authenticated mesh carrier, not a semantic authority.

## dev6: operational relationships over time

The Mesh can now carry **relationship sets** alongside metric snapshots.  A
relationship is a read-only observation with explicit `from_ref`, `to_ref`,
`kind`, `authority`, observation time and optional dimensions/evidence.  A set
adds a scope and says whether it is a complete current projection of that
scope.  Complete sets replace the current view for their exact
`authority + scope_id`; bounded history retains earlier sets for transition
analysis.  Instrumentation never invents topology or a synthetic withdrawal.

Current adapters include:

- RexxOS Grid membership: `HAS_MANAGEMENT_UNIT` and `HAS_MESH_INSTANCE`;
- Queue Channel configuration: `QUEUE_TRAFFIC_TO`;
- LDAP/Identity fenced authority holder: `AUTHORITY_HELD_BY`;
- explicit bridges from Management Relationship Discovery, requiring a
  semantic-reference resolver rather than object display strings.

RTO2 Grid explicitly remains the membership authority, not ACTIVE/SPARE or
workload-placement authority.  Identity peer promotion policy also remains
external; the adapter reports the holder already fenced by the epoch authority.
The generic Management bridge preserves each relationship's declared authority.

The publisher samples metric snapshots and relationship sets in one publication
batch.  The collector validates the whole batch before changing retained state,
then exposes `RELATIONSHIPS_LATEST`, `RELATIONSHIP_SETS_LATEST` and
`RELATIONSHIP_SETS_HISTORY`.  This gives Keynote enough history to animate
operational change while leaving semantic truth with the originating domain.

## dev5: freshness is not health

A NOC must not keep displaying an old `HEALTHY` sample as if it were live.
dev5 therefore records optional authoritative POSIX-second publication time in
`instrumentation.publication/1` and retains detached per-service publication
evidence in the collector.

`InstrumentationFreshnessAssessor` classifies the observation path as:

- `FRESH` — last accepted publication is inside the caller's fresh window;
- `LATE` — outside the normal cadence but not yet beyond the stale threshold;
- `STALE` — no accepted publication inside the stale threshold;
- `UNKNOWN` — no qualified numeric time exists, the caller supplied invalid
  time, or the publication appears to be in the future.

This does **not** convert stale telemetry into service failure.  Publication
failure means observation freshness has been lost; it does not prove that SMTP,
LDAP, IMAP, Storage, Memory, Queue, RexxOS or any application has failed.

The assessor does not parse local clock strings.  Its `nowPosixSeconds` input is
an externally authoritative instant.  Single Time Service v0.4 `TimeInstant`
`ticks` is the intended semantic fit, but Instrumentation Mesh does not require
Single Time Service at runtime.

## Dimensional series

Counters remain keyed by `metric + canonical dimensions`.

Existing `gaugeSet()` behaviour is intentionally preserved for compatibility:
it is the latest point-in-time value for one metric name, and the supplied
dimensions describe that current value.  dev5 adds `gaugeSeriesSet()` for the
case where several dimensional gauge values are simultaneously meaningful.
This avoids silently changing current NoSQLServer and other producers while
providing a non-lossy multi-series gauge surface.

## Current producer shape

The current Library estate already uses the common source protocol:

- Queue Fabric / Queue Channel Fabric;
- Memory Fabric dev10;
- Storage Fabric dev21 plus Storage instrumentation dev1;
- RexxOS RTO2 Grid dev14 controller + current Management Units;
- LDAP Identity dev16;
- HTTPS Server 0.4.7;
- SMTP Secure Stack dev9 through the semantic `smtp.event/0.1` seam;
- IMAP dev13 through `ImapInstrumentationSource`, including session, command,
  IDLE, byte and transport-failure observations without mailbox/content data;
- NoSQLServer v0.88 query/materialisation instrumentation;
- NotNotes Mini Application dev17, with NoSQL telemetry remaining a separate
  source;
- MVS Alchemy service instrumentation;
- finite deployment/application operations through
  `InstrumentationOperationObserver`.

A registered source may expose `snapshot()`, `snapshots()` or
`instrumentationSnapshot()`.  The publisher sends one atomic batch and the
collector validates the complete batch before mutating retained observation
state.

## 3D NOC / Keynote

Wire3D Keynote is the first concrete consumer.  The dev29.20 NOC projection can
discover current instrumented services by authoritative deployment identity
(estate/node or MI) instead of requiring a static list of every service.
Explicit service references in the deployment catalogue remain expectations:
if one is not observed it is reported as `unobservedServices`; it does not
quietly disappear from the NOC.

Wire3D keeps source health and publication freshness separate.  A stale
`HEALTHY` sample remains `health=HEALTHY` plus `freshness=STALE`, allowing the
presentation to show lost observation without fabricating an operational
failure.

Instrumentation Mesh does not create a competing topology/architecture graph.
RexxOS membership, deployment geography, Management relationships and Project
Alchemy interaction descriptions remain with their existing authorities and
may be joined by consumers such as Keynote.

## Bidirectional management

Observation does not imply mutation permission.  A remote command still needs:

1. authenticated Queue/XTP peer identity;
2. the Instrumentation service authorizer;
3. the target service's own operation/authority checks.

Instrumentation Intentions and Management Intention Discovery remain read-only
ways to discover observation state; they do not acquire command authority.
