# Job-to-Node network6 GitHub integration checkpoint

Working archive: `job_node_allocator_v0.6-network6.zip`
SHA-256: `d26153c6f5a70fb8979be34b231d4716d1eb60e8dec4292d89bedc1487b09fe2`.

GitHub main still contains network1; this branch is a documentation/qualification checkpoint, **not** a full source import.

## Authority

Job-to-Node v0.6 retains hard eligibility, WLU admission, leases and owner epochs. The network API remains `job.node.allocator.network/0.1`. Migratable Job/runtime own actual execution and start receipts. Missing acknowledgements and ABSENT observations retain placement.

## Verified source discrepancy

The supplied network6 ZIP's `src/JobNodeExecutionLifecycle.cls` has `sequence+=1` before journal open and silently skips unexpected journal lines during restore. Its actual code therefore **does not implement** the network6 journal-hardening claims in the previous changelog. Treat this as a blocker. The archive integrity check is not executable qualification.

## Remaining work

1. Repair lifecycle journal sequence/restore code in the source.
2. Import the complete source/tests into this branch and compare manifests.
3. Run ooRexx regression and crash/restart fault injection.
4. Check QueueRexx and Migratable Job compatibility.
5. Update sphere qualification with observed results before merging.
