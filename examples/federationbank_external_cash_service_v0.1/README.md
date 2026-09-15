# FederationBank External Cash Service v0.1

Durable service boundary for authorised cash-centre / armoured-carrier shipments.

Commands:

- `FBEXTCASH.SHIPMENT.SUBMIT`
- `FBEXTCASH.SHIPMENT.DISPATCH`
- `FBEXTCASH.SHIPMENT.RECEIVE`
- `FBEXTCASH.SHIPMENT.GET`

Lifecycle:

```text
AUTHORIZED -> IN_TRANSIT -> COMPLETED
                    \
                     -> RECONCILIATION_REQUIRED
```

For outbound shipments the branch vault release occurs before the work becomes `IN_TRANSIT`. For inbound shipments the external shipment becomes `IN_TRANSIT` first and branch physical custody changes only when receipt evidence (manifest/seal/count) is accepted by the vault port.

The service preserves semantic idempotency, durable work state, stable event identities, an at-least-once outbox, and Queue Fabric graph persistence. A receipt discrepancy is retained as reconciliation work rather than flattened into a generic failure.

Branch-Day evidence helpers expose completed inbound/outbound control totals, cash still in transit, and outstanding reconciliation count without turning this service into Branch Day authority.
