# Frankenstack v0.10 — Retained Authority Time Bomb

A deliberately ugly integration test across the current ooRexx toybox:

- Structured Relation Plugin v0.9
- Runtime Registry v0.11
- Legal Effect v0.7
- Object Queue Fabric v0.8.1 (v0.8 runtime; test-only repair release)
- Virtual RYTA / HardWorld v0.19
- NoSQLServer v0.74
- msqlshim v0.12
- ooRexx DB Skeleton / Database Core v0.39

## Scenario

The real OurLadyAir PNRGOV fixture contains group `G07`, where three passengers
have `SSR NSST` (seat not purchased).  Structured Relations retains the native
EDIFACT object/path provenance and honestly reports the fixture's deliberately
invalid outer envelope.

A synthetic seat-together offer (3 x EUR20 = EUR60) is legally `ADMISSIBLE` at
publisher event time on 2026-08-20.  Runtime Registry generation v1 captures
execution evidence.  Broker A publishes the offer as a **persistent retained**
distributed topic while Broker B has no interest, so `remoteManagerCount=0`.

Broker A is restarted.  Runtime generation v2 is activated and a wholly
synthetic Legal Effect norm becomes applicable on 2026-08-21.  Broker B then
subscribes on 2026-08-22.  Queue Fabric delivers exactly one retained
publication and records a durable distribution receipt.  Broker B is restarted
and the same logical remote publication is injected again; the durable receipt
suppresses a second local fan-out.

At consumer time, the same sealed synthetic Legal Effect generation evaluates
the action as `BLOCKED`.  Explicit evidence→authority promotion tells HardWorld
that publisher-time admissibility, queue durability, and historical runtime
evidence are evidence only; they are not permanent current authority.

HardWorld therefore produces:

- `ACT_ON_RETAINED_OFFER` +9,000,000 → `PROHIBITED`
- `TRUST_PUBLISHER_TIME_APPROVAL` +8,000,000 → `PROHIBITED`
- `TREAT_QUEUE_DELIVERY_AS_AUTHORITY` +7,000,000 → `PROHIBITED`
- `RE_EVALUATE_AT_CONSUMER` -1,000,000 → `REQUIRED`
- `PRESERVE_SOURCE_PROVENANCE` -500,000 → `REQUIRED`
- `SUPPRESS_RETAINED_OFFER` -1,000 → `REQUIRED`

## Architectural claim

> A retained event preserves its provenance and delivery history.  It does not
> permanently carry publisher-time legal or business authority.  Authority
> must be re-evaluated when the retained event becomes actionable.

Queue Fabric v0.8's durable receipts demonstrate a local idempotent broker
boundary.  This demo does **not** claim distributed XA or exactly-once network
semantics, and Queue Fabric itself makes no such claim.

## Legal disclaimer

The legal source/norm in this experiment is entirely synthetic test material.
Nothing in this package states or models real law in any jurisdiction.

## Run

A real ooRexx 5.3.0 runtime is required.  Point `OOREXX_ROOT` at its install
prefix if `rexx` is not already on `PATH`:

```bash
OOREXX_ROOT=/path/to/oorexx/usr/local ./run_demo.sh
```

The runner extracts the vendored component archives into a temporary tree,
binds msqlshim v0.12 to the vendored canonical NoSQLServer v0.74, executes
focused current-stack preflights, starts the real MySQL wire listener, queries
it via the bundled small MySQL-compatible client, exercises COM_STMT_PREPARE /
cursor FETCH, attacks read-only evidence tables, and performs an independent
Database Core v0.39 round-trip.
