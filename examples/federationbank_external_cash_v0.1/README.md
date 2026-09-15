# FederationBank External Cash v0.1

Physical-cash shipment authority for movement across the branch perimeter: cash centre / armoured carrier to branch, and branch back to cash centre / carrier.

This module deliberately does **not** model customer cash, customer accounts, Core Banking balances, Ledger entries, or branch-internal till replenishment. It owns the shipment contract and the authority/evidence needed to move a sealed physical bundle across an external custody boundary.

Core concepts:

- `FederationBankExternalCashShipment` — exact inbound or outbound shipment, branch, vault, cash centre, carrier, manifest, seal and denomination-counted bundle.
- `FederationBankExternalCashApproval` — independent checker approval bound to the exact shipment identity.
- `FederationBankExternalCashAuthorityEnvelope` — policy-authorised exact-action authority for the shipment.
- `FederationBankExternalCashReceipt` — receiving evidence binding shipment, seal, counted bundle and receiving custody reference.

A valid shipment authority is not permission to open or alter a branch vault. The receiving/releasing branch custody authority remains independent and is integrated by a separate adapter.
