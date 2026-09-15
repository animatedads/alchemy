# FederationBank Teller Cash v0.1 Architecture

## Purpose

A counter-cash transaction crosses two independent truths:

1. **Core Banking monetary truth** — whether a customer account was debited or credited; and
2. **Teller Till physical truth** — whether a counted bundle of cash entered or left an identified till under valid custody.

Teller Cash correlates those authorities after Staff Authority has established who may request the exact action. It does not merge the authorities.

```text
                    exact customer instruction
                              |
                              v
                        Staff Channel
                              |
                      Staff Authority
                              |
                    exact authority envelope
                              |
                              v
                         Teller Cash
                    /                                        /                                         v                         v
        Core Banking TRANSFER          Teller Till
          monetary authority         physical authority
                  \                         /
                   \                       /
                    +---- correlated -----+
                          cash outcome
```

## Withdrawal choreography

```text
staff-authorised CASH_WITHDRAWAL
              |
              v
translate exact Core TRANSFER
customer -> settlement
              |
              v
        Core Banking commit
              |
       +------+------+
       |             |
   rejected       committed
       |             |
 no cash release     v
                physical CASH_OUT
                     |
               +-----+-----+
               |           |
             success     failure
               |           |
           COMPLETED   COMPENSATION_REQUIRED
```

A Core transport failure is not a Core rejection. The Staff Channel keeps `READY_FOR_CORE`, and Teller Cash resumes the already `PREPARED` Till work using the same exact translated command identity.

## Deposit choreography

```text
staff-authorised CASH_DEPOSIT
              |
              v
        physical CASH_IN
              |
        cash now in custody
              |
              v
translate exact Core TRANSFER
settlement -> customer
              |
       +------+------+
       |             |
    commit          failure
       |             |
   COMPLETED    RECONCILIATION_REQUIRED
```

The cash remains a custody fact even when the customer-account credit has not committed.

## Non-goals

v0.1 deliberately does not implement:

- branch vault inventory or vault/till replenishment;
- till skims and branch cash movements;
- cash ordering/transport/courier custody;
- denomination optimisation or counterfeit-note machinery;
- ATM withdrawal/hold semantics;
- direct Ledger access;
- staff UI or Wire UI projection.
