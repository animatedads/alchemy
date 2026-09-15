# Branch Day evidence model

Branch Day Evidence is an adapter/assembler, not a new source of truth.

It projects:

- Branch Cash vault state and internal cash-in-transit/reconciliation;
- Teller Till expected/count/discrepancy state;
- Teller Cash completed customer cash-in/out and unresolved physical/monetary work;
- External Cash completed inbound/outbound movements, external in-transit cash and unresolved external reconciliation.

The resulting `FederationBankBranchDayEndpointEvidence`, `FederationBankBranchDayPositionEvidence`, and `FederationBankBranchDayControlTotals` are evidence snapshots for Branch Day certification. The originating authorities retain ownership of their facts.
