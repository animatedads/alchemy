# FederationBank Branch Day Evidence v0.2

Typed evidence adapters for Branch Day certification.

The assembler projects authoritative vault and till state into Branch Day endpoint evidence, derives branch position including in-transit and unresolved work, derives customer cash-in/out from Teller Cash service work, and derives external cash-in/out from External Cash service work. It does not rewrite those sources into a new truth store.

v0.2 qualifies the full External Cash -> Branch Cash vault -> Branch Day chain: a carrier/cash-centre shipment changes the real branch vault only through exact External Cash authority plus current Branch Cash dual custody; the resulting physical position and external control total then reconcile at end of day.
