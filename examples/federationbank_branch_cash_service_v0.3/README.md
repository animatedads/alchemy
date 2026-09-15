# FederationBank Branch Cash Service v0.3

Durable service boundary around Branch Cash physical custody authority.

Commands:
- `FBBRANCHCASH.TRANSFER.SUBMIT`
- `FBBRANCHCASH.TRANSFER.RESUME`
- `FBBRANCHCASH.TRANSFER.RESOLVE`
- `FBBRANCHCASH.TRANSFER.GET`

The service coordinates vault/till custody endpoints but has no customer-account, Core Banking or Ledger port. Once source custody is released, the cash becomes an explicit `IN_TRANSIT` custody item until the destination accepts it. Destination failure becomes `RECONCILIATION_REQUIRED`, retaining the exact transfer and transit custody reference.

## Till integration boundary

The service continues to expose a neutral idempotent `TILL` endpoint protocol rather than reusing Teller Till customer `CASH_IN` / `CASH_OUT`. `federationbank_branch_till_adapter_v0.1` maps that protocol to Teller Till v0.2's separate internal-cash instruction, preserving the distinction between customer cash and bank-owned replenishment/skims.

## v0.3 authority-bearing endpoint protocol

Every physical endpoint call now carries the typed exact-action Branch Cash authority envelope. The service durably records `AUTHORISED` before releasing source custody. Endpoint adapters must reject missing, forged, or transfer-mismatched authority rather than accepting a caller-created authority reference.
