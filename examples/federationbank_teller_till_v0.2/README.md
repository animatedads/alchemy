# FederationBank Teller Till v0.1

Domain semantics for physical counter-cash custody. This package deliberately does **not** model a teller as an ATM and does not own customer account or Ledger truth.

It models till identity, branch/custodian context, opening float, counted denominations, cash-in/cash-out physical movement, exact-action checker approval, discrepancies, and dual-control closure. A bank transaction and a physical cash movement are separate facts which must later be correlated by the Staff Channel/Teller Cash orchestration boundary.

## v0.2 internal branch cash

Teller Till now has a separate `FederationBankTillInternalCashInstruction` path for branch-cash replenishment, skim and till-to-till custody movement. It requires a Branch Cash authority reference, exact checker approval and current till custody. These operations do not carry customer/account/Core command fields and are not represented as customer cash transactions.
