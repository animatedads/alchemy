# Teller Cash Service Boundary

## Ownership

The service owns **coordination state only**.

It does not own:

- employee identity or role truth;
- maker/checker policy;
- customer account balances;
- Core Banking policy/legal/security decisions;
- physical till inventory;
- Ledger mutation;
- CRM/case state;
- UI navigation.

## Command flow

```text
FBTELCASH.ACTION.SUBMIT
          |
          v
persist exact request + instruction + receipt
          |
          v
Staff Channel Service
          |
     Staff Authority
          |
     +----+----------------------+
     |                           |
APPROVAL_REQUIRED          READY_FOR_CORE
                                 |
                                 v
                       Teller Cash dispatch
                         /                                      v                v
                  Core Banking       Teller Till
                         \              /
                          +------------+
                               |
                      correlated outcome
```

## Recovery contract

The service persists a new work and command receipt **before** downstream mutation. When downstream Staff Channel reaches `READY_FOR_CORE` but Core delivery fails, the Teller Cash work stays `READY_FOR_CORE`.

A retry uses the same Teller Cash work/instruction but sends a distinct internal `FBSTAFFCH.ACTION.RECOVER` command to Staff Channel. The Staff Channel then retries its already-authorised exact bound Core command. Teller Cash resumes the already-prepared Till work, so the Till service does not mistake idempotent `SUBMIT` replay for execution.

## Result interpretation

- `CORE_REJECTED`: Core saw the command and institutionally refused it; for withdrawals physical cash is not released.
- `READY_FOR_CORE`: Core transport/delivery did not complete; exact retry remains available.
- `COMPENSATION_REQUIRED`: Core withdrawal debit committed, but physical release failed.
- `RECONCILIATION_REQUIRED`: physical deposit cash was accepted, but customer credit did not complete.
- `COMPLETED`: both required authorities reached their intended committed outcomes.

This vocabulary is deliberately richer than a generic success/error flag.
