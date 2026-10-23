# Changelog

## 0.2
- Added `arch.layered-audio.memory-local-execution` for the Audio V9 / Memory Fabric adaptive-horizon execution model.
- Recorded the authority split: Memory Fabric owns resident block identity/fencing, Job-to-Node owns admission/placement, Queue Fabric carries runner/control state, Storage Fabric owns durable material identity, and Audio remains cluster-unaware.
- Recorded the commit ordering rule: destination MOVE acknowledgement precedes Memory Fabric cursor advance and horizon-demand satisfaction.
- Recorded fail-closed cases for missing residency, stale block/provider epochs, unverified placement and uncertain Queue Fabric delivery.
- Added durable lessons for execution-to-memory locality and handoff commit ordering.
- Updated qualification continuity to the October 2026 Memory Fabric dev10 / RTO2 Grid dev14 / Storage Fabric dev21 estate and the candidate20 Autobuild submissions, without claiming pending r13196 cross-package runtime qualification.

## 0.1
- Added explicit allocator-boundary retrieval lesson and qualification search.
- Initial authoritative Layered Audio / Audio Processing Toolkit continuity sphere from implementation v0.23 and historical processing-method corpus.
- Initial sphere scaffold.
