# ConnectSelector, RPC Service Core and Single Time Service

Source packages independently checked from the Library on 2026-10-09:
ConnectSelector dev2, RPC Service Core dev1, JSON-RPC Fabric dev3, and
Architecture Intentions dev6. No source was copied into this package.

## Owned authorities

* Time Service: time rules, civil resolution, recurrence intentions, timezone
  versions, candidate instants and explanations. It does not submit jobs.
* ConnectSelector: chooses DIRECT, RPC, or QUEUE under exact authorized policy
  and required semantics. Only ConnectSelector may decide routes. Unsupported
  alternatives are not retrofitted into a live request after an uncertain send.
* RPC Service Core: explicit registration of approved receiving ooRexx object
  methods; `time.zone.resolve -> TimeServiceEndpoint~zoneResolve` etc. Distinct
  from protocol method labels and wire encoding.
* JSON-RPC Fabric: JSON-RPC 2.0 request/reply and optional transport. It does
  not supply durable Queue Fabric semantics. The binder is optional and only
  supports the approved operations.
* Serialisation Selector: future wire schema choice, not temporal semantics.
* Queue Fabric: optional durable scheduling orchestration performed by the
  *consumer* of a time projection; no queue objects imported by the time core.

## Enqueue semantics

`time.recurrence.expand` is a read-only request, not an enqueue. Any future
intention-registration operation needs separate authorisation, ID allocation,
revision/optimistic concurrency, durable storage, idempotency and re-projection
when tzdb rules change. It cannot be claimed by existing `time.zone.resolve`.
If a caller later submits a particular occurrence to Queue Fabric, the caller
must carry an intended local time, selected instant, IANA zone ID, tzdb edition,
source intention and chosen gap/fold policy. Queue acceptance is not completion.

## JSON value protection

The optional `TimeJsonRpcHandler` serialises only declared integer fields
(e.g. `instantPosixSeconds`, `offsetSeconds`, `generatedCount`) as JSON numbers.
An ID like `007` remains a JSON string. GAP evidence uses JSON `null` for the
nonexistent instant; it must not be submitted as a runnable job. The JSON-RPC
loopback integration test is a protocol round trip, **not** a claimed live
network/TLS test.

## Policy and coverage

No implicit current time or host-local timezone. Clients supply explicit
IANA identifiers, local readings or POSIX instants. Clock providers, natural
language resolvers, semantic intentions, event persistence and holiday
calendars remain future independently governed layers.

## v0.5 event resolution operation

`time.event.resolve` (DIRECT request or JSON-RPC request) and the RPC Core
registered method `time/event.resolve` carry `institution`, `phrase`, `onDate`.
Returns semantic resolution and zero or more occurrence records. The event
catalog is an optional injection into `TimeServiceEndpoint`; without it,
the operation fails closed. No new selector, queue or RPC dispatcher is created.
Catalog mutations and event/calendar changes are *not* published remotely.

## v0.6 authority reads

An endpoint can accept a `TimeAuthorityLedger` instead of a raw
`TimeEventCatalog`. `time.event.resolve` optionally accepts numeric
`asOfRevision`, with a revision-specific evidence checksum in the result.
`time.authority.info` returns read-only revision, head checksum, integrity
classification and single-writer durability limitations. `time/authority.info`
is explicitly registered in RPC Service Core. Neither operation allows clients
to mutate calendars, events, aliases, or journal records. ConnectSelector's
`ENQUEUE` remains separately gated and is not implemented by this service.
