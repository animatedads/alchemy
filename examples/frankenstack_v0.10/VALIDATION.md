# Validation

Built and executed on Open Object Rexx 5.3.0 r13196 (2026-08-03 internal test
build), 64-bit.

The build-tree acceptance completed with:

```text
FOCUSED CURRENT-STACK PREFLIGHT: OK
FRANKENSTACK V0.10 PREPARED CURSOR: OK
DATABASE CORE FRANKENSTACK V0.10 FACADE: OK
FRANKENSTACK V0.10 RETAINED AUTHORITY TIME BOMB: OK
```

Focused preflight includes:

- NoSQLServer v0.72 general JOIN ON smoke, running on v0.74 source
- Structured Relations v0.9 OurLadyAir PNRGOV seat-offer smoke
- Queue Fabric v0.8 distributed topic and durable recovery smokes
- Runtime Registry execution-evidence acceptance
- Legal Effect v0.7 core acceptance
- HardWorld TableFeed authority matrix (18 vectors, zero holes)
- Database Core v0.39 compile smoke

The integration itself additionally verifies:

- native G07 EDIFACT source identity/path survives into rich evidence;
- outer PNRGOV envelope remains `INVALID` rather than being hidden;
- Runtime Registry detached v1 evidence stays `ACTIVE` while the live v1 lease
  becomes `DRAINING` after v2 activation;
- publisher legal status is `ADMISSIBLE`, consumer legal status is `BLOCKED`;
- persistent retained publication survives Broker A restart before any remote
  interest exists;
- late Broker B interest causes one retained handoff;
- Broker B durable receipt survives restart and suppresses duplicate ingress;
- Queue Fabric's own distributed topic state is projected read-only through
  NoSQLServer v0.74;
- HardWorld authority beats arbitrarily high preference scores;
- prepared MySQL cursor inspection does not re-execute the HardWorld provider;
- structured evidence, Queue snapshots, receipts, and decisions reject SQL
  mutation;
- Database Core v0.39 independently reads the same state over msqlshim v0.12.

For packaging acceptance the exact final ZIP is also run with
`SKIP_PREFLIGHTS=1`; this skips only the already-recorded component preflights
and still executes the complete v0.10 integration, MySQL wire/cursor probes,
mutation attacks, and Database Core round-trip.
