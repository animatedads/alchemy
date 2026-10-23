# Job-to-Node network6 integration checkpoint

Source package prepared: `job_node_allocator_v0.6-network6.zip`.
SHA-256: `d26153c6f5a70fb8979be34b231d4716d1eb60e8dec4292d89bedc1487b09fe2`.

This branch is a synchronization checkpoint, **not yet the complete source import**. The repository currently contains network1; network2–network6 source and tests must be imported from the qualified archive before merging.

## Authority invariants

- Job-to-Node v0.6 owns eligibility, WLU admission, placement leases and ownership epochs.
- Network API remains `job.node.allocator.network/0.1`.
- Migratable Job starter and destination runtime own actual execution and durable start receipts.
- An uncertain remote start retains placement; missing acknowledgement or ABSENT observation is never proof of safe release.
- Lifecycle evidence is bound to job, placement and ownership epoch, and cannot override allocator authority.
- COMPLETED evidence permits explicit release but never automatically releases a lease.

## Changes since network1

- network2: fixed-precision millisecond epoch boundary, tests for adjacent millisecond expiry.
- network3: evidence-driven lifecycle PLACED/DISPATCHED/ACCEPTED/RUNNING/COMPLETED and durable journal.
- network4: terminal-state immutability and contiguous committed sequence validation.
- network5: conservative RUNNING/ABSENT/UNKNOWN runtime observation reconciliation.
- network6: sequence commit handling and fail-closed unknown/multiple uncommitted journal records.

## Qualification gate

The archive has passed ZIP integrity and static review. Network3–network6 runtime changes have **not** passed ooRexx executable regression in this environment. Do not merge to main or advertise deployment qualification until the full source import, interpreter tests, crash/restart fault injection and downstream QueueRexx/Migratable Job compatibility tests complete.
