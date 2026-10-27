# Changelog

## 0.1-dev8 — explicit correlation/causation context

- Added optional `causation_id` and `context_refs` to `instrumentation.event/1`
  while retaining compatibility with dev7 event records that omit both fields.
- Added `instrumentation.correlation/1` and `InstrumentationCorrelationView`.
  Groups are formed only by non-empty source-supplied `correlation_id`; no
  timestamp, host, topology, health or severity inference is permitted.
- Correlation groups preserve collector acceptance order, all contributing
  authorities, subjects/related/context refs, source-vs-derived counts, display
  severity and producer-declared causation edges.
- Added event filtering by `causation_id`, `context_ref` and `related_ref`.
- Added generic `InstrumentationEventObserver` for event-only domain authorities.
- Extended `InstrumentationOperationObserver` lifecycle events with optional
  correlation, causation and context refs without breaking existing callers.
- Added qualification proving same-time uncorrelated events remain separate,
  cross-authority explicit correlation works, causation is not inferred, and
  dev7 additive event records remain accepted.
- Preserved all dev7 replay, bounded-history, relationship, freshness, fabric
  and management-authority boundaries.

## 0.1-dev7 — operational event timeline and bounded-history repair

- Added `instrumentation.event/1` with source authority, semantic subject,
  severity, correlation/operation identity, related refs, bounded evidence and
  explicit `derived` provenance.
- Publications now carry optional event arrays and receipts report newly
  accepted events. Repeated retained source events are deduplicated by
  authority + event id across later successful publication sequences.
- Added `EVENTS` / `EVENTS_HISTORY` collector queries.
- `InstrumentationOperationObserver` emits replay-safe operation lifecycle
  events while preserving the existing progress snapshot contract.
- Collector derives `HEALTH_CHANGED`, `RELATIONSHIP_BECAME_VISIBLE` and
  `RELATIONSHIP_CEASED_VISIBLE` observations only from accepted evidence. These
  events use `INSTRUMENTATION_OBSERVER` authority and never claim the source
  authority performed a transition.
- Repaired bounded Array retention in snapshot, relationship and event history.
  The implementation no longer assumes `Array~remove(1)` compacts indexes.
- Qualified Storage Fabric Instrumentation Mesh dev3 through the dev7 event
  timeline and reran the complete dev6 regression suite.


## 0.1-dev6

- Added `instrumentation.relationship/1` and `instrumentation.relationship-set/1`.
- Added atomic publication/collector retention for metric snapshots plus relationship sets.
- Added latest relationship, latest relationship-set and bounded relationship-set history queries.
- Added complete-scope replacement semantics without fabricated withdrawal events.
- Added Queue Channel `QUEUE_TRAFFIC_TO` relationship projection.
- Added RexxOS Grid `HAS_MANAGEMENT_UNIT` / `HAS_MESH_INSTANCE` projection without inventing ACTIVE/SPARE state.
- Added Identity peer epoch `AUTHORITY_HELD_BY` projection while retaining external promotion authority.
- Added explicit Management Relationship bridge requiring semantic-reference resolution.
- Qualified current Network Transport Intentions v0.1-dev3 as a compatible domain relationship source model.
- Preserved all dev5 freshness, history, dimensional-series and management-authority boundaries.

## 0.1-dev5

- Added optional `published_posix_seconds` to complete publications and retained
  per-service publication evidence in `InstrumentationCollector`.
- Added `InstrumentationFreshnessAssessor` with FRESH/LATE/STALE/UNKNOWN states,
  explicit future-time rejection and caller-owned policy windows.
- Kept freshness distinct from source health; stale telemetry is not service
  failure authority.
- Added explicit `gaugeSeriesSet()` / dimensional `gaugeValue()` while preserving
  established `gaugeSet()` latest-value semantics for current producers.
- Qualified current IMAP dev13 semantic instrumentation including IDLE.
- Qualified current NoSQLServer v0.88 query instrumentation against dev5.
- Qualified NotNotes Mini Application dev17 plus independent NoSQL telemetry
  against dev5.
- Added Keynote/Wire3D dev29.20 dynamic node/MI discovery, missing expected
  service visibility and separate observation freshness projection.
- Reaffirmed that Instrumentation Mesh does not duplicate Project/Management/
  deployment topology authority.

## 0.1-dev4

- Added common snapshot/snapshots/instrumentationSnapshot source composition,
  dimension-aware counters, usage analysis, SMTP semantic-event adaptation and
  generic finite-operation progress.
