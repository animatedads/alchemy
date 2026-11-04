# v0.8: rule data now has a retained identity

TimeZoneRuleSnapshot is implemented as an explicit **archived TZif dataset**,
with edition, immutable publication identifier, per-zone SHA-256 witnesses,
and the exact source bytes needed to reproduce an earlier UTC projection.
The archive publisher is deliberately offline and administratively invoked;
the runtime loads an explicitly named, previously verified archive. The
snapshot revision differs from institutional authority journal revisions.
Both are supplied to an impact projection; neither silently revises the other.

An impact report still carries its old/new calendar revision witnesses and
per-zone `tzdbEdition` derived from `<edition>@<snapshot>#sha256:<digest>`.
The source path in rule metadata is an archival reference, not the host's
current TZif location. Ambiguities, gaps and unsupported future tails retain
their earlier fail-closed semantics. A TZif archive does not make POSIX future
rules magically understood: unsupported future projections still fail.

**Security boundary:** SHA-256 verification is a provisioning step, not
signed historical authority; a malicious filesystem administrator can replace
both archive and manifest. Native Adler32 is only for accidental corruption.
Applications requiring attestation must use separate trustworthy signing and
key authority. No startup automated network download or trust-on-first-use.

---

# v0.7 addition — impact projections and consumer-controlled observation

Single Time Service computes **changes to temporal meaning**, without implementing event transport or executing schedules. `TimeImpactAnalyzer` compares two committed institutional revision snapshots over a bounded explicit civil date window. Its `TimeChangeWatch` offers optional local pull-and-ack with a caller-persisted checkpoint, but does not create a messaging fabric, timer, or durable subscription. See `docs/IMPACT_ANALYSIS.md`.

---

# Single Time Service: domain and intentions

## Fundamental invariant
Never infer an instant from a local clock reading without place, date, rules and
a documented ambiguity policy. Never interpret a place name as a timezone ID
without geographic resolution and confidence.

## Domain boundaries
1. **Measurement:** UTC-labelled time, POSIX seconds, TAI, monotonic elapsed time,
   wall clocks, simulated/virtual clocks, synchronization quality and uncertainty.
2. **Representation:** Instant, CivilDateTime, Duration, CalendarPeriod, ZonedTime,
   TimeInterval, TimeWindow, BusinessCalendar, CalendarSystem.
3. **Authority:** IANA TZif releases, leap-second bulletins, calendars, statutory
   alterations, historical confidence, sources, date of knowledge (as-of queries).
4. **Meaning:** TimeIntent, TemporalExpression, PlaceReference, MealConvention,
   LocaleContext, SchoolTimetable, TimeEvent, EventOccurrence, TimeResolution.
5. **Operations:** now(), offsetAt(), differencesAt(), transitionsBetween(),
   resolveCivil(), convertInstant(), interpret(), expandRecurrence(),
   findAvailability(), timeline(), explain(), compareRulesAsOf().

## Wall clock ambiguity
- Fall-back fold produces two candidate instants; return both unless policy given.
- Spring-forward gap produces no candidate; explicitly propose adjustment policies.
- A time-only expression ('six') is an incomplete specification, not 18:00 by fiat.
- Meals are locally governed events, not universal fixed timestamps.
- Times may be approximate, deadline, preference, event-relative or interval.

## Natural intentions
- 'Dinner time' -> needs location/social or institutional setting and relevant date.
- 'School dinner' -> institution and its term/timetable (often midday in UK English).
- 'Supper' -> culturally and personally variable meal convention.
- 'When the Sydney office opens' -> office calendar and zone; not necessarily sunrise.
- 'Same time tomorrow' -> preserve wall-clock time or elapsed duration? ask / policy.
- 'The difference last week' -> specify an instant/date and zone identifiers; may
   vary within the requested range across DST transitions.
- '31 October' -> year, region, time within the day where transitions could occur.

## Provenance and ruleset updates
Every response should carry canonical zone IDs, snapshot versions, applicable
UTC offsets, timestamps, transition explanation, evaluation as-of time,
ambiguity status and sources. Preserve rule versions for audit/replay. A future
political change generates changed projections, not mutation of past evidence.

## Calendar and recurrence contracts
Separate elapsed seconds from civil days/months/business days. Distinguish
anchored instant, floating local time, zoned recurring time and event-relative
conditions. Recurrence expansion obeys gap/fold policies and retains original
intent and exception calendars.

## Communication boundaries
Direct ooRexx invocation is the default library path. Offer standalone JSON-RPC
2.0 API via interchangeable transport. Optional Queue Fabric may persist event
intents, retries, watches and occurrences. JSON-RPC notifications do not imply
confirmed delivery; Queue Fabric provides separate durable semantics.

## Security / governance
Clock providers cannot set a trusted institutional clock simply by returning
an offset. Policy changes require versioned authority. Requests carry locale,
zone/calendar scopes, source and resolution policy. Never execute event actions
without governed authorization. Timestamp parsing rejects ambiguous and
out-of-range inputs rather than guessing.

## Roadmap
1. Deterministic core and bounded tests (this delivery).
2. Native read-only TZif v2/v3/v4 and IANA alias providers (full history).
3. Civil conversion, gap/fold and complete transition suite.
4. ISO/Gregorian + configurable institutional calendars and meal semantics.
5. Time intentions, event recurrence, observability and provenance ledger.
6. JSON-RPC provider and Queue Fabric bridge; portable Windows/Unix adapters.
7. Leap seconds, TAI, monotonic-clock, simulated time and high precision.

## Tests needed before production claim
Historical sub-hour offsets, negative epochs, 2038+, southern/northern DST,
Lord Howe 30-minute shifts, date-line jumps (Samoa), ambiguous short zone
abbreviations, unknown identifiers, tzdb revision changes, leap-second policy,
gap/fold examples, business-calendar overrides and provider failure.

## Implemented in v0.2
`resolveLocal` enumerates each bounded rule period, inverts that period's
numeric offset, and verifies the inverted instant belongs to the same period.
This produces zero, one, or multiple possible instants without assuming hourly
DST increments. For normal timezone datasets there are at most two; atypical
rules can theoretically produce more than two, and future implementations must
preserve all results. The current two-element sorting optimisation needs to be
replaced by a general stable chronological sort before arbitrary tzdb import.
No parser, TZif loader, astronomical timescale or reliable clock source is
claimed yet. Rule-period coverage remains an injected authority obligation.

## v0.3 implementation and qualification boundary (2026-10-08)

Native `TzifZoneProvider` (RFC 9636 format) decodes the version 2+/64-bit
section in a TZif file, including signed transition instants, transition type
indices, offsets and NUL-separated designations. Also accepts legacy v1 files.
The core uses the POSIX timescale, so leap-aware TZif files fail closed.

A TZif file's trailing POSIX rule supplies transitions *after* the last
explicit transition. `v0.3` captures but does not evaluate recurring DST
rules. Only validated fixed-UTC-offset footers can continue indefinitely. An
unsupported recurring footer imposes a fail-closed horizon on instant queries,
local resolution and transition enumeration. At the horizon the current
implementation deliberately declines some potentially valid local readings,
not just invalid ones, to avoid ungrounded candidate results. This policy is
safer than guessing a future offset but should eventually be replaced by a
full POSIX TZ parser and ruleset expansion.

`IsoCivilClock` introduces strict civil date/time construction and formatting,
without consulting the host timezone. It uses proleptic Gregorian arithmetic
rather than conflating a local calendar reading with a UTC instant. The
`explainDifferenceAt` report carries both local projections, zone IDs, offsets,
abbreviations, and both injected tzdb editions.

The canonical authority seam remains `SingleTimeService~registerZone`:
provider inputs are replaceable. Neither `Queue Fabric` nor `JSON-RPC` is
required to use the library; neither transport has been implemented here.

Qualified cases: British autumn fold/spring gap; Sydney/London 9/10/11-hour
changes across October 2026; Lord Howe 30-minute transitions; Samoa's skipped
2011-12-30; Kathmandu fractional-hour offset; Brisbane/Sydney divergence;
Chatham 45-minute offset; Gregorian leap years; negative POSIX instants; a
synthetic >2038 TZif v2 table; legacy v1; invalid/truncated input and rejected
leap-aware TZif v4. Future IANA revisions and historical provenance still
require a controlled tzdb installation/snapshot policy.

Next increments: POSIX recurrence footer evaluator with bounded horizon,
version-pinned tzdb bundle registry and alias provenance, intent/date phrases,
calendar periods versus elapsed durations, event recurrence and clocks,
standalone JSON-RPC 2.0, optional Queue Fabric dispatch bridge.

## v0.4 implementation: named civil recurrence and explicit endpoint publication (2026-10-09)

A `TimeRecurrenceSpec` is an *intention*, not a list of UTC timestamps. It
records a stable local civil anchor, zone identifier, daily or weekly calendar
frequency and interval, a weekday mask for weekly schedules, and explicit gap
and fold policies. The expansion engine projects that intention across a
specified inclusive local window using the exact injected timezone rules.
In particular, a UK 09:00 weekly intention stays 09:00 while its UTC mapping
changes from 08:00 to 09:00 at the autumn clock change.

The supported DST gap decisions are SKIP, RECORD (a non-executable GAP
occurrence with no instant), and REJECT. The supported fold decisions are
EARLIER, LATER, BOTH, and REJECT. No implicit relocation to the end of a gap
or assumption that any fold is exactly one hour is acceptable. Every projected
instant has POSIX seconds, offset seconds, designation, tzdb edition and an
explicit selection label. An unexpanded TZif POSIX future rule still blocks
queries beyond documented coverage.

Daily intervals are civil days, not multiples of 86,400 elapsed seconds.
Weekly intervals count ISO Monday-based calendar weeks from the week of the
anchor, not elapsed seven-day UTC durations. Outputs are read-only projected
records; they are neither saved as events nor submitted as jobs. Execution is
owned by a separate authorized scheduler or Queue Fabric consumer.

The service endpoint exposes exactly `time.zone.resolve`,
`time.zone.compare`, and `time.recurrence.expand`. A `TimeServiceEndpoint`
implements a narrow `request/notify` interface usable by ConnectSelector's
pre-existing `ConnectCallAdapter`, but intentionally returns false for notify:
these synchronous information requests are not subscription events.
`publishTo(registry)` uses RPC Service Core's atomic `registerObject()` and
leaves freeze, inbound authentication, authorization and lifecycle to the
caller. The optional JSON-RPC binding converts approved values without
misrepresenting numeric-looking identifiers as JSON numbers. It was exercised
with the real JSON-RPC Fabric and ConnectSelector in a loopback transport only.

The supported dependencies were checked from the Library: ConnectSelector
v0.1-dev2, RPC Service Core v0.1-dev1, JSON-RPC Fabric v0.1-dev3, and
Architecture Intentions v0.1-dev6. Core compilation and operation require
none of them. Integration tests resolve exact source roots rather than
searching for arbitrary package duplicates.

Future work includes monthly and yearly civil periods, holiday/business
calendar exception authority, richer intention/event taxonomy, DST shift
policies, updates to timezone-rule versions with re-projection/reconciliation,
full POSIX TZif rule footer expansion, temporal clock authority, and
intentional Queue Fabric persistence/dispatch as a distinct operation family.


## v0.5: contextual events / institutional time

Time meaning is **not** determined by its label alone. A phrase is interpreted
under a named institution and calendar revision, with an explicit target date.
The resolver accepts only pre-registered phrases; it has no LLM, implicit locale,
implicit current date or permission to invent institution-specific schedules.

* Calendar authority decides which dates are closed. An event-level move cannot
  reopen a closed institution. A schedule is evaluated after closure and
  cancellation checks; a weekend event cannot be created by a simple time move.
* Event authority owns named event identity, local clock/elapsed duration,
  recurrence and dated exceptions. Durations are elapsed SI/POSIX seconds,
  not calendar minutes or an implied end-wall-reading across a DST change.
* Catalog authority owns mappings of institution+phrase to event identifiers.
  Registration and withdrawal are immediate; ambiguity is a first-class result.
* The implementation exposes read-only `time.event.resolve` via the existing
  service endpoint. ConnectSelector decides DIRECT/RPC/QUEUE; the time service
  neither persists nor dispatches jobs. JSON-RPC remains optional and explicit.
* Calendar/event/catalog revisions are in-memory evidence and must not be
  confused with authenticated change authorities or persistent snapshots.
  A durable next increment would require immutable revisions, governance,
  storage, notifications, replay, rule database updates and optimistic locking.

This v0.5 interpreter is intentionally a **structured intention resolver**,
not a generic natural-language comprehension engine. Social conventions like
'dinner', 'supper' and 'school dinner' become explicit institution-owned
bindings rather than guessed cultural facts.

## v0.6 durable authority (2026-10-10)

Institutional temporal authority is an append-only command log with an explicit
sequence. Calendar/event revisions can be reconstructed at any committed
sequence. The runtime rule provider is injected, not stored in the journal.
This is distinction between *a decision definition valid as known at sequence N*
and *recreating a past UTC projection using a specific timezone data edition*.
The latter additionally requires the historical TZif snapshot.

Management mutations are local-only and require the expected journal revision;
ConnectSelector, RPC Core and JSON-RPC publish read-only resolution/metadata.
The journal format is line-delimited STS6, bounded hex-encoded strings and a
chained rolling checksum. It is a single-writer, best-effort persistence
substrate. Hash-chain consistency is not authentication. It is not a scheduler.


## v0.9: publication as an explicit boundary

`TimeChangePublication` produces a typed advisory impact delta; it is not a publisher, a scheduler or an acknowledgement service. The consumer selects DIRECT, RPC or Queue Fabric via ConnectSelector subject to policy.
