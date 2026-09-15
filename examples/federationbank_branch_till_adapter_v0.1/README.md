# FederationBank Branch Cash ↔ Teller Till Adapter v0.1

A narrow physical-custody adapter between Branch Cash authority and Teller Till custody.

It accepts only a typed `FederationBankBranchCashAuthorityEnvelope` which exactly matches the Branch Cash transfer. It then translates that authorised transfer into the existing Teller Till v0.2 internal-cash instruction and requires an independent Till checker approval before the till moves physical expected cash.

The adapter has no customer-account, Core Banking, Ledger, CRM, or Staff Channel route. Branch Cash decides whether the internal branch transfer is authorised; Teller Till independently decides whether the current drawer custodian and physical-count operation may accept/release it.
