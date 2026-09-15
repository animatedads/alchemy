# Validation

Qualified on 2026-08-26 with **Open Object Rexx 5.3.0 r13196 — Internal Test Version** against the supplied FederationBank/API closure.

## Executable tests

**6/6 pass**:

1. counted physical bundle must exactly equal the staff-authorised amount;
2. deposit translation produces settlement-account -> customer Core transfer without claiming physical receipt;
3. cash instruction registration is immutable per Staff Channel command identity;
4. runtime module/capability contract;
5. Core translation refuses a command without exact Staff Authority evidence;
6. withdrawal translation produces customer -> settlement-account Core transfer without claiming physical release.

## Static compilation

All **4/4** package `.cls` files, including test support, pass `rexxc` under the same dependency closure.

## Important observed properties

- `CASH_WITHDRAWAL`/`CASH_DEPOSIT` never enter Core Banking unchanged.
- Counter cash has no ATM dependency and no Ledger port.
- Staff Authority evidence is mandatory before monetary translation.
- Counted bundle amount/currency, custodian, branch and exact Staff Channel command are bound before execution.
- Till approval, when present, forms part of the instruction semantic identity.
- Retrying an already-prepared Till work uses `resume`, preventing an idempotent Till `SUBMIT` receipt from being misinterpreted as execution.

The complete command/test output is retained in `VALIDATION_TRANSCRIPT.txt`.
