# Job-to-Node Allocator engineering sphere

## Authority and baselines

The original v0.6 source baseline is `job_node_allocator_v0.6.zip` (SHA-256 `58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead`).

GitHub main currently carries `packages/job_node_allocator_v0.6-network1/`, not the latest local continuation. A candidate `job_node_allocator_v0.6-network6.zip` (SHA-256 `d26153c6f5a70fb8979be34b231d4716d1eb60e8dec4292d89bedc1487b09fe2`) is awaiting source import and runtime qualification. This sphere documents that candidate; it does not claim network6 is merged or deployed.

Public APIs remain `job.node.allocator/0.6` and `job.node.allocator.network/0.1`.

## Ownership boundary

Job-to-Node owns hard eligibility, WLU-backed admission, placement leases, ownership epochs and fencing. Queue Fabric transports messages but is not execution authority. Migratable Job owns durable starter receipts, execution idempotency and migration coordination; the runtime owns actual execution. A remote start with no reply must retain placement; neither missing acknowledgement nor an ABSENT runtime observation proves a job can safely be restarted.

## Continuation history

- network2: authority millisecond-epoch precision boundary and focused tests.
- network3: evidence-bound lifecycle state and append-only lifecycle journal.
- network4: terminal-state and sequence validation intentions.
- network5: conservative runtime RUNNING/ABSENT/UNKNOWN observation seam.
- network6: journal hardening intention; see the qualification discrepancy below.

## Source inspection finding — 2026-10-23

Direct inspection of the supplied network6 ZIP found that `src/JobNodeExecutionLifecycle.cls` still contains `sequence+=1` **before** journal open succeeds and that `restoreInto` still skips unexpected records with `if line~left(7)<>"COMMIT|" | pending="" then iterate`. Thus the previously stated network6 journal-hardening claims are **not present in the supplied source**. This is an open source/validation mismatch, not a passed fix. Do not advance this package to production on the strength of the network6 changelog alone.

## Required acceptance

Import and compare every source/test file with the archive, fix the journal source mismatch, then run the complete ooRexx test matrix, failure injection at event/commit boundaries, durable restart, exact epoch T/T+1ms tests, and QueueRexx/Migratable Job integration. Record interpreter build, dependencies, hashes and observed results. Keep source claims, test evidence and release authority distinct.

For source archaeology, use the exact ZIP and the shared ooRexx archive/source examiner. This sphere is documentation/continuity, not an executable authority.
