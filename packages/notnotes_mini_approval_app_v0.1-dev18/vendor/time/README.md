# Single Time Service v0.3 — native ooRexx time-domain core

Executable, connector-independent ooRexx service for instants, civil readings,
actual IANA TZif timezone transition data and explicit local-time ambiguity.
It is **not** yet a complete time-intention or calendaring system.

## New in v0.3

- `TzifZoneProvider`: native read-only binary decoder for TZif v1, v2, v3 and v4
  (`RFC 9636`). For v2+ it uses the **64-bit** table, not the legacy 32-bit table.
- Fetches transitions, types, UTC offsets and zone designations from a
  trusted, explicitly configured data root. Rejects unsafe lexical identifiers,
  bad headers/counts/indices, truncation and unsupported leap-second tables.
- Explicit `edition`, `sourcePath`, `posixTail` and `coverageEnd` metadata.
  The provider never guesses the tzdb edition: pass a version identifier from
  the data supplier (e.g. `2025b`), not the operating system build number.
- Bounded future coverage: POSIX footer **fixed offsets** are understood;
  dynamic POSIX DST recurrence rules are retained but not executed. For a
  dynamic tail, queries after the final recorded transition fail closed.
- Native `IsoCivilClock~parseLocal('YYYY-MM-DDTHH:MM:SS')` and `~formatLocal`.
  Strict proleptic Gregorian calendar, years 0001–9999, whole seconds. No
  ambiguous parsing, implicit UTC conversion, leap-second `:60`, or OS TZ.
- `SingleTimeService~resolveIsoLocal`, `~isoLocalAt`, `~explainDifferenceAt`
  for convenient date-specific human-facing comparisons and provenance.
- Binary-search instant lookups; all local-resolution candidates are
  chronologically ordered, with no two-candidate limit.
- Duplicate registered zone IDs rejected to prevent silent snapshot mutation.

## Installation and tests

Requires ooRexx 5.3 runtime. No Python or other runtime dependency is required.

```sh
# From package root
REXX_PATH="$PWD/src" rexx tests/edge_zones.rex
REXX_PATH="$PWD/src" rexx examples/london_sydney.rex
./tools/run_tests.sh
```

`tools/run_tests.sh` uses `REXX` if supplied, otherwise `rexx` on PATH.
For the attached portable test environment the package was tested with the
user-supplied ooRexx 5.3.0 r13196 x86-64 runtime. All tests use bundled
self-contained TZif fixtures (IANA tzdata 2025b snapshot, extracted from the
container's `/usr/share/zoneinfo`) or small synthetic TZif files. Application
use should load from a provisioned immutable/snapshotted tzdb directory.

## Direct OO usage

```rexx
provider = .TzifZoneProvider~new('/usr/share/zoneinfo', '2025b')
time = .SingleTimeService~new
time~registerZone(provider~load('Europe/London'))
time~registerZone(provider~load('Australia/Sydney'))

resolution = time~resolveIsoLocal('Europe/London', '2026-10-25T01:30:00')
say resolution~status                         /* FOLD */
say resolution~choose('EARLIER')~ticks
say resolution~choose('LATER')~ticks

one = time~resolveIsoLocal('Europe/London','2026-10-31T12:00:00')
explanation = time~explainDifferenceAt('Europe/London', 'Australia/Sydney', one~choose('ONLY'))
```

### API summary

| API | Meaning |
|---|---|
| `provider~load(zone)` | Read TZif file for canonical IANA ID |
| `service~registerZone(rules)` | Install one snapshot, no overwrite |
| `service~offsetAt(zone, instant)` | UTC offset in seconds at specified instant |
| `service~differenceAt(a,b,instant)` | b offset minus a offset at that instant |
| `service~explainDifferenceAt(a,b,instant)` | Civil readings, zone abbreviations, offsets, edition |
| `service~resolveIsoLocal(zone,isoLocal)` | Zero, one or multiple candidate instants |
| `service~transitionsBetween(zone,a,b)` | Transition periods within `[a,b)` |
| `service~zoneMetadata(zone)` | Edition, source, footer, period count, horizon |
| `IsoCivilClock~formatLocal(localReading)` | Local coordinate to Gregorian wall reading |

`TimeInstant` in v0.3 represents **POSIX whole seconds**, not TAI or leap-second
UTC. Local readings are naive coordinates, not absolute instants.

## Authority and limits

- TZif is a *format*, not a clock and not a timezone-political authority. Zone
  data is versioned by its external publisher. The user passes an explicit
  edition for auditable output.
- The fixed test fixture is **2025b**. It is not a live-updating tzdb and
  must not be treated as authoritative for future political changes.
- A dynamic POSIX footer is **not yet** expanded to arbitrary future years.
  Out-of-coverage queries fail rather than continuing the last offset.
- Leap-second-aware `right/` TZif files are explicitly rejected.
- Time-only utterances, location ambiguity, natural-language meals, recurrence,
  UTC/TAI conversion, high precision and JSON-RPC transport are not implemented.
- `loadZone` must be used with an administrator-trusted data root. Lexical path
  validation is not an OS filesystem sandbox against untrusted symlinks.
- tzdb aliases work when the trusted root exposes them, but an alias/canonical
  provenance registry is future work.
- Windows and Termux validation are still outstanding.

See `DESIGN.md` for the time-domain boundary, `contracts/time-service.v1.json`
for proposed external JSON-RPC shape, and `tests/` for deterministic evidence.
