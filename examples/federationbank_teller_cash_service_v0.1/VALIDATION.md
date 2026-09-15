# Validation

Qualified on 2026-08-26 with **Open Object Rexx 5.3.0 r13196 — Internal Test Version** against the supplied FederationBank/API closure.

## Executable tests

**13/13 pass**:

1. Core Banking institutional rejection prevents withdrawal cash release;
2. Core transport outage leaves exact work `READY_FOR_CORE` and replay completes it once;
3. full deposit chain: physical cash acceptance then Core customer credit;
4. deposit with failed Core credit becomes `RECONCILIATION_REQUIRED` while cash remains held;
5. Staff maker/checker and Till physical checker remain independent controls;
6. explicit proof that counter cash does not route through ATM semantics;
7. at-least-once service event outbox retry without rolling back committed work;
8. permanent Queue Fabric recovers the full typed Teller Cash command graph after queue-manager reconstruction;
9. runtime module/capability contract;
10. outer service command idempotency spans both monetary and physical effects;
11. typed service state/instruction survives durable service restart;
12. withdrawal Core debit followed by physical-release failure becomes `COMPENSATION_REQUIRED`;
13. full withdrawal chain: customer instruction -> Staff Authority -> Core transfer -> Till cash release.

## Static compilation

All **5/5** service package `.cls` files, including integration/runtime/test support, pass `rexxc` under the same dependency closure.

## Recovery fault probe

A fail-once Core transport is injected after Staff Authority has succeeded. The first call leaves Teller Cash and Staff Channel at durable `READY_FOR_CORE`; no account or physical-cash movement occurs. Replaying the same semantic Teller Cash command resumes the existing Till work and the exact Core command commits once.

## Persistent Queue Fabric probe

A full typed Teller Cash service envelope containing the nested Staff Channel request, custody context and physical instruction is put to a **permanent** Queue Fabric queue. The queue manager and service boundary are then reconstructed before consumption. A fresh codec/worker recovers and processes the graph; Core posts once and the Till releases the exact physical amount once.

## Important observed properties

- Core institutional rejection and Core infrastructure failure are not conflated.
- `COMPENSATION_REQUIRED` and `RECONCILIATION_REQUIRED` are durable institutional work, not generic errors.
- Service state persists the exact Staff Channel request and exact Teller Cash instruction.
- Recovered instructions are immutably re-registered before the service accepts new work.
- Event delivery is at least once with stable IDs and does not roll back committed cash work.
- No ATM or direct Ledger route is introduced.

The complete command/test output is retained in `VALIDATION_TRANSCRIPT.txt`.
