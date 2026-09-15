# FederationBank Branch Cash v0.3

Physical branch vault custody and branch-internal cash-transfer authority, now with an explicit external-cash custody boundary.

External cash from/to a cash centre or armoured carrier is **not** represented as customer cash and is not disguised as an internal `VAULT/TILL` transfer. `FederationBankBranchCashExternalInstruction` carries the exact shipment, amount, currency, manifest, seal and upstream External Cash authority reference. The open vault independently requires its current two-person custody control before physical cash can enter or leave.

The module owns branch physical-custody truth only. It does not own customer accounts, Core Banking balances, Ledger entries, or the carrier/cash-centre shipment lifecycle.
