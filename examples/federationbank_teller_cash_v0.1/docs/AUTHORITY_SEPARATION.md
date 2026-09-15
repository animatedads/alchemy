# Authority Separation

FederationBank Teller Cash v0.1 is intentionally composed from independent authorities.

| Question | Authority |
| --- | --- |
| Is this a legitimate Staff Channel journey? | Staff Channel policy |
| May this employee request/approve this exact action now? | Staff Authority |
| May this account actually be debited/credited? | Core Banking + its policy/legal/security chain |
| Did these exact notes enter/leave this exact drawer? | Teller Till Authority |
| Did the Ledger commit monetary truth? | Core Banking/Ledger boundary, not Teller Cash |

Passing one authority does not imply passing another.

## Forbidden shortcuts

The module has no valid path for any of the following:

```text
teller role -> Ledger mutation
physical cash count -> customer balance
Core transfer success -> assume notes handed over
notes received -> assume account credited
ATM hold/withdrawal -> pretend it was teller cash
```

## Settlement account

The internal cash-settlement account is the monetary counterpart used for Core `TRANSFER` translation. It is not the till itself and is not a substitute for physical-cash inventory. Future branch/vault accounting may add richer internal settlement structure without changing this separation.

## Maker/checker

Staff maker/checker and Till physical-cash checker are separate controls. A supervisor who approves the Staff Action has not thereby certified the physical bundle, and a Till approval does not grant workforce authority to perform the banking action.
