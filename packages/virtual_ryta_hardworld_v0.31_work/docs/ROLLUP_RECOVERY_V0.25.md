# RYTA v0.25-work roll-up

Canonical upstream bundle: `oorexx-libs(20260822-crypto-consolidated)(7).zip`.
Outer SHA-256: `e95f489b0088c7d11d31f3b04ac7d2bc766661c6e103a0cfaec8292ffe5203c1`.

Sealed release checkpoint remains `virtual_ryta_hardworld_v0.23`.
`v0.24-work` introduced the Alchemy Objects house base and native Legal Effect
v0.10 authority.  `v0.25-work` layers retained-event consumer-time authority
revalidation on top without modifying any upstream package.

## New invariant

The Frankenstack retained-authority scenario is promoted from an application
warning into a RYTA execution invariant:

```text
retained publisher-time authority != consumer-time authority
queue durability                 != authority
historical runtime provenance    != authority
```

Queue Fabric's native `oqf.topic.retained` and `oqf.topic.publication_id`
headers define the transport fact.  RYTA requires consumer-time revalidation
before ledger `START` for retained replays.

## Legal Effect v0.10

The native retained Legal adapter accepts an engine object, a live runtime rule
lease, action and context.  It performs the pinned and runtime-bound evaluations
inside the queue revalidation call.  A precomputed Legal execution envelope is
not an input to this adapter.

The canonical consumer context id comes from `LegalEffectEvaluationInputSnapshot`.
The action/context are snapshotted again after the live lease evaluation; drift
fails closed.  A released lease adversary confirms that a prior successful
consumer evaluation cannot be cached and reused as current authority.

The known Legal Effect REVIEW/STATUS_EFFECT + REQUIRES_OBLIGATION reducer-order
ambiguity remains guarded as `LEGAL_STATUS_REDUCTION_AMBIGUOUS`.

## Queue replay

The v0.21 START/COMPLETE/ACK model remains non-XA.  Retained revalidation is an
additional gate before START.  A refusal leaves the package claimed/inflight so
host policy can back out, quarantine or otherwise handle it.

The consumer promotion set must be sealed, distinct from the publisher set, and
canonically different from it.  Merely deep-copying publisher promotions does
not manufacture new authority.

## Validation

Executed under the user-supplied Open Object Rexx 5.3.0 r13196 debug build:

- complete v0.25 current-stack runner: PASS;
- generic retained replay adversaries: PASS;
- native Legal Effect v0.10 retained consumer-time path: PASS;
- released Legal runtime lease adversary: PASS before ledger START;
- inherited self-contained HardWorld/Librarian corpus and static guards: PASS;
- 40/40 RYTA `.cls` files compile with `rexxc`;
- canonical current-library lock: 29/29 package/file entries verified;
- exercised upstream Alchemy Objects, crypto, Camera, Structured Relation,
  Legal Effect, Runtime Registry, Queue Fabric and NoSQLServer trees are
  byte-for-byte pristine against fresh extraction.

See `docs/RETAINED_AUTHORITY_REVALIDATION_V0.25.md` for the authority contract.
