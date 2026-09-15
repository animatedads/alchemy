# FederationBank Teller Cash v0.1

Cross-authority domain/orchestration module for **branch counter cash**. It connects an already policy-governed FederationBank `STAFF` channel action to Teller Till physical custody and to an ordinary Core Banking monetary transfer, without treating a teller as an ATM and without introducing a Ledger bypass.

## Boundary

The module introduces the staff-channel operations `CASH_WITHDRAWAL` and `CASH_DEPOSIT`. They are first authorised as exact staff actions by Staff Authority. Only the staff-authority-bound command may be translated into the ordinary Core Banking `TRANSFER` which changes monetary truth. Physical cash still moves only through Teller Till Authority.

```text
customer instruction
      |
      v
Staff Channel ---> Staff Authority
      |                 |
      |            exact-action envelope
      v                 |
Teller Cash <-----------+
   |             |
   |             +----> Core Banking TRANSFER
   |                     (monetary truth)
   v
Teller Till
(physical custody truth)
```

There is deliberately no ATM dependency and no Ledger port.

## Exact binding

`FederationBankTellerCashInstruction` binds:

- one Teller Cash work identity;
- one original Staff Channel command identity;
- withdrawal/deposit direction;
- exact till and branch settlement account;
- exact counted `FederationBankCashBundle`;
- exact custody context;
- optional exact Till checker approval.

Its semantic identity includes the Till approval when present. Re-registering the same Staff command with different cash semantics is rejected as `CASH_INSTRUCTION_CONFLICT`.

`FederationBankTellerCashCoreTranslator` additionally requires the Staff Authority evidence already bound into the Staff Channel command. It never accepts a bare teller request as monetary authority.

## Monetary translation

Counter-cash operations are **not Core Banking operations**. After Staff Authority succeeds they translate deterministically:

- withdrawal: customer account -> branch/internal cash-settlement account;
- deposit: branch/internal cash-settlement account -> customer account.

The translated command keeps the original staff-authority provenance plus Teller Cash/till/custody evidence. Translation says nothing about whether notes were physically received or released.

## Physical sequencing

The dispatch port binds the translated Core command to one exact `FederationBankTillAction` and delegates sequencing to Teller Till Service.

For withdrawals, Core commits before physical release. If physical cash cannot then be released, the institutional outcome is `COMPENSATION_REQUIRED`.

For deposits, physical cash is accepted before Core credit. If Core cannot complete the credit, the institutional outcome is `RECONCILIATION_REQUIRED`.

True Core transport/delivery failures are kept distinct from policy, funds, account or other institutional rejections. A retry resumes the already-prepared Till work instead of replaying a Till `SUBMIT` receipt as though it were execution.

## Runtime capability surface

`FederationBankTellerCashRuntimeModule` advertises:

- `COUNTER_CASH_ORCHESTRATION`
- `STAFF_AUTHORITY_BINDING`
- `CORE_TRANSFER_TRANSLATION`
- `PHYSICAL_TILL_BINDING`
- `COMPENSATION_OUTCOME`
- `RECONCILIATION_OUTCOME`
- `NO_ATM_SEMANTICS`

See `docs/ARCHITECTURE.md` and `docs/AUTHORITY_SEPARATION.md`.
