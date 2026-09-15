# Service boundary

The service owns orchestration state and durable correlation, not physical facts owned by endpoint authorities. External endpoint ports must be idempotent by exact transfer identity because delivery/retry is at-least-once.

State progression:

`PREPARED -> AUTHORISED -> SOURCE_RESERVED (vault source only) -> IN_TRANSIT -> COMPLETED`

or:

`IN_TRANSIT -> RECONCILIATION_REQUIRED -> RETRY_DESTINATION -> COMPLETED`

An internal cash movement never becomes a customer deposit/withdrawal merely to reuse a Core Banking route.


Every endpoint release/accept call now carries the typed Branch Cash authority envelope. The generic endpoint protocol therefore cannot be used to make a non-vault route silently skip Branch Cash policy or checker validation.
