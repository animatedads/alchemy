# Recovery model

The durable state contains branch vault snapshots, exact transfer work, semantic command receipts, audit events and the pending outbox. A work item in `IN_TRANSIT` or `RECONCILIATION_REQUIRED` is branch custody evidence: the amount is included in branch total custody but in neither endpoint balance until accepted.


The exact Branch Cash authority envelope is part of durable work state. Restart must recover the same authority identity; it is never regenerated from a bare transfer after source custody has moved.
