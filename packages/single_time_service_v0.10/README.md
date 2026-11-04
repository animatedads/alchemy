# Single Time Service v0.10 — time-validity uncertainty seam

New: `src/TimeValidityWindow.cls`, `tests/validity_window.rex`, and `docs/TIME_VALIDITY.md`. These pure ooRexx objects accept explicit UTC uncertainty bounds and distinguish definite pre-validity, expiry, inside-window and indeterminate time results. They **never** authorize a certificate, LDAP credential, connection or job; security owners retain chain, private CA, LDAP, cryptographic time-source, and application access decisions. No live host clock or remote input is silently trusted. The native test is included but requires a separately provisioned ooRexx executable.

# Single Time Service v0.9 — version-pinned timezone rule snapshots

**Complete replacement source tree based on v0.7**, with a new optional, read-only
archive layer. Historical timezone data is not fetched implicitly and no
transport or clock authority is substituted by the snapshot mechanism.

## What is new

- `tools/time_snapshot.py`: explicit, create-only snapshot publication of TZif
  bytes, canonical sorted manifests, SHA-256 and Adler32 evidence, offline
  verification, and changed/added/removed zone comparison. The publisher
  rejects traversal, symlink escapes, malformed inputs, duplicate snapshots,
  altered data and malformed manifests.
- `src/TimeRuleSnapshots.cls`: native ooRexx `TimeRuleSnapshotCatalog`, which
  inspects a pinned manifest and constructs a `SingleTimeService` from selected
  zones. It checks the archived TZif bytes against the manifest's Adler32 and
  parses those *same bytes* through `TzifZoneProvider~loadBytes`.
- `TzifZoneProvider~loadBytes` refactors the existing reader so source files and
  archived in-memory bytes undergo exactly the same TZif validation. Its
  existing `load`/`loadPath` API is preserved.
- Read-only `TimeImpactAnalyzer~new(ledger,oldService,newService)` now works
  with **actual archived rule snapshots**, not merely hand-built test rules.
- Two packaged TZif snapshots demonstrate one fixture dataset and a deliberately
  synthetic changed London rule. Synthetic rules are NOT historical UK facts.

## Execution and qualification

The offline Python snapshot tests **passed** in this workspace. The native
`tests/rule_snapshots.rex` test and v0.7 full suite are present, but have NOT
been executed during this increment: the previously supplied ooRexx debug `.deb`
is visible as a conversation attachment without downloadable binary backing,
and the current container has no ooRexx executable. Prior v0.7 test claims
must not be presented as a fresh v0.8 qualification.

Run `python3 tests/test_snapshot_tool.py` for the archive tool, then install
or point `OOREXX_RUNTIME_ROOT` at the prescribed ooRexx 5.3.0 runtime and run
`sh tools/run_tests.sh` for the ooRexx semantic and connector regression suite.

The archive is a **trusted local configuration asset**. The service does not
claim runtime SHA-256 verification or signed rule provenance: offline SHA-256
verifies the installed bytes, ooRexx Adler32 checks accidental in-process data
corruption, and administrative controls must protect the snapshot directory.
No scheduler, publishing loop, subscription or Queue Fabric implementation is
added. ConnectSelector remains the optional communication owner.

See `docs/TZDB_SNAPSHOTS.md` and `examples/pinned_rule_comparison.rex`.

---

# Single Time Service v0.7 — semantic impact and change observation

This is a **complete replacement delivery** built on the accepted v0.6 source.
It extends durable historical authority with **read-only day-scoped impact
analysis**, typed difference evidence, and an optional in-process, pull-only
change watch. Every semantic operation remains independent of transport.

- New `src/TimeImpactAnalysis.cls`: `TimeImpactAnalyzer` and `TimeChangeWatch`.
- New `TimeAuthorityLedger~revisionWitness(revision)` exposes non-cryptographic
  historical head evidence without revealing the catalog or journal path.
- New read-only `time.impact.analyze` with explicit RPC Core registration,
  ConnectSelector DIRECT, and JSON-RPC Fabric loopback adapter support.
- Detection distinguishes intention changes, local-wall-time changes,
  UTC projection shifts, timezone-rule edition changes, gaps/folds,
  cancellations and institutional closures. An unaltered event is not flagged
  merely because an unrelated journal revision occurred.
- Optional **local pull** `TimeChangeWatch`: `poll`, explicit `acknowledge`,
  and `checkpoint`. Consumer must persist checkpoints; no durable subscriptions,
  background monitoring or Queue Fabric enqueue are provided.
- Full qualification: original v0.6 regressions and new impact, fold, watch,
  ConnectSelector, RPC Core and JSON-RPC integration tests on ooRexx
  5.3.0 r13196 using the v0.6-pinned optional dependencies.

See `docs/IMPACT_ANALYSIS.md`, `contracts/time-impact-v0.7.json` and
`examples/impact_change.rex`.

**Critical distinction:** the old and new institutional definitions are
compared using the same injected timezone provider at the remote endpoint.
To assess a timezone rule update, trusted local code explicitly injects
separate old/new providers. This release does not retain historical TZif
bytes or make a historical proof out of a non-cryptographic checksum.

---

# Single Time Service v0.6 — durable temporal authority

This increment extends v0.5 with an **optional, local append-only authority journal**.
The domain remains ooRexx-native and independent of ConnectSelector, JSON-RPC,
Queue Fabric or any clock service. All earlier APIs remain available.

## What v0.6 adds

- `TimeAuthorityLedger.cls` writes versioned calendar, named-event, closure,
  event exception, phrase binding and phrase withdrawal commands to a
  single-writer journal. Every successful mutation consumes exactly one
  monotonically increasing integer revision.
- `resolveCurrent(context,phrase,date,timeService)` evaluates current
  definitions; `resolveAt(context,phrase,date,timeService,asOfRevision)`
  reconstructs historic definitions from the committed journal prefix.
  It emits `authoritySequence`, revision-specific `authorityHeadChecksum`,
  and an integrity classification.
- A restart replays the journal through the same ordinary domain classes.
  Invalid event commands are rejected **before** append. A checksum-invalid,
  malformed, missing-commit or truncated journal is rejected rather than
  partially recovered. Revision conflicts reject stale writes, including
  same-sequence replacement of journal history.
- `TimeServiceEndpoint~new(timeService,ledger)` exposes read-only
  `time.event.resolve` (optional `asOfRevision`) and `time.authority.info`.
  Both work through existing ConnectSelector DIRECT, explicit RPC Service
  Core registration, and JSON-RPC Fabric loopback. JSON numbers and string
  identifiers remain distinct. No journal-management operation is remotely
  published.

### Local authority example (revisions are required for every mutation)

```rexx
::requires 'TimeAuthorityLedger.cls'
ledger=.TimeAuthorityLedger~new('/trusted/config/school-time.journal')
rev=ledger~revision
rev=ledger~addCalendar('SCHOOL','Europe/London','term-2026',rev)
rev=ledger~addEvent('meal-007','SCHOOL','School dinner','MEAL', -
    '2026-10-01','2026-12-31','12:15:00', -
    'WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-r1',rev)
rev=ledger~bindPhrase('SCHOOL','dinner','meal-007',rev)
/* Supply a configured .SingleTimeService with Europe/London rules. */
result=ledger~resolveAt('SCHOOL','dinner','2026-10-26',timeService,rev)
```

See `examples/authority_history.rex` and `docs/AUTHORITY_JOURNAL.md`.

### Qualification and deliberate limits

- Verified using supplied ooRexx 5.3.0 r13196; core regressions, journal
  tampering/truncation rejection, restarted state, historical lookup,
  ConnectSelector dev2 + RPC Core dev1 + JSON-RPC Fabric dev3 loopback.
- **Single-process writer only**; no locks, no atomic multi-record transactions,
  no directory fsync, no replication, no signed audit history. Each journal
  record has a complete marker and a chained non-cryptographic checksum that
  detects ordinary corruption but **is not tamper-proof**. A closed stream
  is not a storage-fsync guarantee. A damaged tail requires operator recovery.
- Historic `asOfRevision` changes the *institutional definitions*, not the
  TZif data supplied at query time. To reproduce the exact previously
  calculated instant after a government rule change, the caller must retain
  the original TZif edition and original resolution evidence. The journal
  does not yet archive binary timezone data or maintain signed time decisions.
- No job dispatch, scheduler, JMS bridge, event subscriptions, network server,
  or automatic tzdb re-projection is supplied by this increment.

## v0.5 — institutional events and contextual intentions

Native ooRexx service for *what civil time means*, grounded in version-pinned
TZif rule data. Supersedes v0.4 without changing its `SingleTimeService`,
`TimeZoneRules`, `IsoCivilClock`, and `TzifZoneProvider` public interfaces.

## Added in v0.5 — Named temporal intentions

**Executable ooRexx implementation, not generic natural-language understanding.**
`TimeInstitutionCalendar` supplies a named institution, IANA timezone,
explicit revision and dated closures. `TimeNamedEvent` supplies an event identity,
classification, valid date range, local clock time, daily/weekly recurrence,
**elapsed** duration and dated cancellations/moves. `TimeEventCatalog` dynamically
binds and unbinds phrases *within* named institutions and resolves a phrase on
an explicitly provided Gregorian date. The same phrase can yield distinct
meanings for different institutions; competing meanings in one institution
return `AMBIGUOUS`, never an invented default.

Date- and clock-validation, gap/fold handling, zone provenance, closure
precedence and recurrence projection reuse the existing v0.4 engine. Responses
record the calendar authority revision, event revision, catalog mutation counter,
and timezone database edition. Mutations increment local revision counters;
these in-memory identifiers are **not** signatures, durable audit journals or
optimistic-concurrency tokens. Catalog mutation is a trusted management
operation, **not** exposed through the RPC endpoint.

`TimeServiceEndpoint~new(timeService[, eventCatalog])` now publishes read-only
`time.event.resolve` / RPC Core `time/event.resolve`. Required parameters:
`institution`, `phrase`, `onDate` (`YYYY-MM-DD`). Responses may be `RESOLVED`,
`GAP`, `FOLD`, `CLOSED`, `CANCELLED`, `NOT_SCHEDULED`, `OUT_OF_SCOPE`,
`UNKNOWN_CONTEXT`, `UNKNOWN_EXPRESSION`, or `AMBIGUOUS`.
The JSON-RPC adapter preserves numeric durations and epoch seconds, and keeps
numeric-looking event identities as JSON strings. DIRECT and JSON-RPC loopback
through the genuine ConnectSelector packages are regression-tested.

Example: `examples/school_dinner.rex`. Tests: `tests/time_events.rex`,
`tests/events_rejects.rex`, `tests/event_endpoint.rex`, `tests/event_json_rpc.rex`.
The school closure in the example is illustrative, **not** an asserted school
holiday schedule for any real institution.

## Delivered in v0.4

- `TimeRecurrenceSpec`: a named intention (local anchor, IANA zone, frequency,
  interval, optional weekday mask and explicit DST gap/fold rules). This is NOT
  a series of hardcoded UTC timestamps. Supports `DAILY` and `WEEKLY` schedules
  with bounded expansion. `WEEKLY` supports ISO weekdays `MO,TU,WE,TH,FR,SA,SU`
  and intervals anchored to the calendar week containing the initial reading.
- `TimeRecurrenceEngine`: projects occurrences within an explicitly supplied
  inclusive local window. No system clock, global timezone, calendar server,
  scheduler, or external service is consulted. Bounded days and records.
- `TimeOccurrence`: projected local datetime, chosen POSIX-second instant,
  applied UTC offset, timezone abbreviation, rule edition and fold choice.
  A nonexistent reading may be returned as `GAP` with `.nil` instant and must
  **never** be treated as an executable timestamp.
- `TimeServiceEndpoint`: an allowlisted `request`/`notify` endpoint for
  ConnectSelector's `ConnectCallAdapter` and explicit registration into
  `RpcServiceRegistry` with `registerObject`. Exposes `time.zone.resolve`,
  `time.zone.compare` and `time.recurrence.expand`, plus optional `time.event.resolve`. No arbitrary ooRexx
  method names may cross the service boundary.
- Optional `TimeJsonRpcBinding.cls`: a JSON-RPC Fabric handler for these same
  operations, with explicit schema-aware numeric/string projection. Tested via
  the real `JsonRpcClient` and loopback transport through ConnectSelector.
  **Not** a network server or new routing implementation.

## Temporal policies

| Situation | Available policy | Consequence |
| --- | --- | --- |
| Ordinary wall reading | automatic UNIQUE | one occurrence |
| Spring gap / skipped day | SKIP | omit nonexistent occurrence |
| Spring gap / skipped day | RECORD | return GAP evidence, no instant |
| Spring gap / skipped day | REJECT | fail the expansion |
| Autumn fold | EARLIER / LATER | select an explicit candidate |
| Autumn fold | BOTH | return each candidate as a separate occurrence |
| Autumn fold | REJECT | fail the expansion |

No automatic shift through a gap is provided. That is a different social and
business rule requiring an explicit, versioned adjustment policy.

`expand(spec, fromIso, throughIso[, maxDays, maxRecords])` includes both
window boundaries. Defaults: maxDays=366 and maxRecords=2000. Hard safety
limits: maxDays <=3660 and maxRecords <=10000. Crossing incomplete timezone
future coverage fails closed; output bounds fail instead of truncating.

## Native usage

```rexx
::requires 'TzifZoneProvider.cls'
::requires 'TimeRecurrence.cls'

provider=.TzifZoneProvider~new('/usr/share/zoneinfo','PROVISIONED-TZDB-EDITION')
time=.SingleTimeService~new
time~registerZone(provider~load('Europe/London'))
pattern=.TimeRecurrenceSpec~new('office','Europe/London', -
    '2026-10-23T09:00:00','WEEKLY',1,'MO,TU,WE,TH,FR','SKIP','EARLIER')
occurrences=.TimeRecurrenceEngine~new(time)~expand(pattern, -
    '2026-10-23T00:00:00','2026-10-30T23:59:59')
do occurrence over occurrences
    say occurrence~localIso occurrence~instant~ticks occurrence~offsetSeconds
end
```

## ConnectSelector and RPC integration

Verified against the exact Library packages:

- ConnectSelector `oorexx.connect_selector/0.1` **0.1-dev2**
- RPC Service Core `oorexx.rpc_service_core/0.1` **0.1-dev1**
- JSON-RPC Fabric `oorexx.json_rpc_fabric/0.1` **0.1-dev3**

The ordinary time domain has no dependency on these packages. For direct
routing, inject `TimeServiceEndpoint~new(time)` as a ConnectCallAdapter
`request/notify` connector. Default-deny `ConnectRoutePolicy` must grant
precise `(operation,mode,provider,destination)` tuples.

For server-side RPC Core registration, call:

```rexx
registry=.RpcServiceRegistry~new
endpoint=.TimeServiceEndpoint~new(time)
endpoint~publishTo(registry)
registry~freeze
reply=.RpcServiceDispatcher~new(registry)~invoke('time','zone.resolve',args)
```

For actual JSON-RPC encoding, use the optional `TimeJsonRpcHandler` and
register individual public method strings with `JsonRpcMethodRegistry`.
The working invocation example is `tests/json_rpc_integration.rex`.

`REQUEST` produces synchronous results; `NOTIFY` is deliberately unsupported
by the time endpoint (a response is not a subscription); `ENQUEUE` requires
a separately authorised and provisioned Queue Fabric adapter. The time core
**does not own** event execution and never pretends a queue PUT means a
scheduled event has completed. JMS interop also belongs to ConnectSelector.
See `docs/CONNECTOR_INTEGRATION.md`.

## Run all tests

```sh
OOREXX_RUNTIME_ROOT=/exact/path/to/extracted-runtime \
TIME_CONNECT_ROOT=/exact/path/to/oorexx_connect_selector_v0.1-dev2 \
TIME_RPC_CORE_ROOT=/exact/path/to/oorexx_rpc_service_core_v0.1-dev1 \
TIME_JSONRPC_ROOT=/exact/path/to/oorexx_json_rpc_fabric_v0.1-dev3 \
./tools/run_tests.sh
```

Omit all three `TIME_*_ROOT` variables for independent core-only regression.
The runner rejects partially specified integration roots; it never searches
for an arbitrary duplicate version. The `OOREXX_RUNTIME_ROOT` layout is the
root extracted from a `.deb`, containing `usr/local/bin/rexx`.

## Explicitly out of scope

No clock synchronization, UTC leap-second representation, calendar services,
monthly/yearly recurrence, exceptions/holidays, natural-language meal
resolution, callback streaming, persisted intention registry, simulated time,
completion events, automated replanning after tzdb updates or production TCP
security is implemented. The v0.3 TZif provider continues to fail closed
where recurring POSIX DST footer rules are outside explicit coverage; a future
release must implement that footer grammar rather than assume a fixed offset.
Fixture TZif files represent a bounded `2025b` test snapshot.


## v0.9 additive: temporal change publication

`src/TimeChangePublication.cls` projects bounded, deterministic advisory change records, with no claimed transport or durable delivery. See `docs/CHANGE_PUBLICATION.md`; `tests/change_publication.rex` is the corresponding native test.
