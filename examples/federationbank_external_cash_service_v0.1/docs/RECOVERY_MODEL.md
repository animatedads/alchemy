# Recovery model

`AUTHORIZED`, `IN_TRANSIT`, `COMPLETED`, and `RECONCILIATION_REQUIRED` are durable institutional states.

A restart does not recreate a shipment as a new request. The original shipment identity, exact authority, custody state, command receipt and pending event identity are recovered. Event delivery is at least once; consumers de-duplicate using stable event identities.
