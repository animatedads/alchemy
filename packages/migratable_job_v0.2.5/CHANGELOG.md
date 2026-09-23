# v0.2.5 — 2026-09-15

- Added `migratable.job.remote-start/1` for managed remote initial `NEW` execution over Queue Fabric direct request/reply queues.
- Added destination-side placement revalidation immediately before standard starter entry.
- Added `MigratableJobJobNodeNetworkLeaseVerifier` using authoritative `job.node.allocator.network/0.1` `CHECK`; destinations no longer need resident allocator state.
- Added a separate durable remote-start RPC ledger binding `startId` to the exact lease/start request/response; conflicting reuse fails closed as `REQUEST_ID_CONFLICT`.
- Exact remote-start replay survives service/ledger reconstruction without a second workload start.
- Queue dispatch uncertainty is now `START_PENDING_PLACEMENT_HELD`, not a false failure and never automatic placement release.
- Hardened Migratable Job epoch-millisecond handling end-to-end: high-precision construction, durable receipt/journal/provenance parsing, and integer serialization validation no longer depend on ooRexx default `NUMERIC DIGITS 9`.
- Fresh network lease checks use per-check unique request ids rather than rounded epoch text. Remote-start replay identity excludes transport send time, so exact semantic retries replay while changed lease/start bindings fail closed.
- All v0.2.4 core, starter, managed placement, file/manual, Storage Fabric, Queue Fabric handoff and retained-status regressions remain green.

# v0.2.4 — 2026-09-14

- Added standard managed initial placement API `migratable.job.placement/1`.
- Added read-only `PLAN` with per-node eligibility reasons and deterministic advisory ranking.
- Added authoritative `CHECK`, `ALLOCATE`, `START`, `ALLOCATE_START`, and `RELEASE` operations over Job-to-Node v0.6.
- Initial `START` now has a reusable placement-bound path which verifies the exact current Job-to-Node lease before `migratable.job.start/1` is entered.
- Allocation retry recognises the same verified current lease as `PLACED_REPLAY` instead of creating a second owner.
- `ALLOCATE_START` deliberately retains placement after failed/ambiguous start (`START_FAILED_PLACEMENT_HELD`); release is explicit.
- Added `MigratableJobPlacedStartExecutor` seam plus local-node reference executor, leaving room for Queue Fabric remote initial-start dispatch without changing placement authority.
- Added SHA-256 protected `migratable.job.placement.receipt/1` audit evidence linking placement and starter execution identity.
- Existing migration destination placement remains under the coordinator/Job-to-Node handoff path; v0.2.4 does not introduce a second migration authority.
- Full v0.2.3 regression estate plus Storage Fabric, Queue Fabric, retained subscriber status and two new managed-placement probes pass.

# v0.2.3 — 2026-09-14

- Adds the standard `migratable.job.start/1` entry contract with `NEW`, `RECOVER` and `HANDOFF` modes.
- Adds durable digest-protected start-id receipts. `CLAIMED` is written before runtime side effects; successful `RUNNING` receipts replay the existing execution reference without a second runtime start.
- Reusing a start id with a different request binding fails closed as `START_ID_CONFLICT`; corrupted receipt streams fail closed before execution.
- Defines the workload seam `MigratableJobStarterApplication`: stable definition plus idempotent `startNew(request, definition)`. The `startId` is the required NEW-execution idempotency key.
- Adds `MigratableJobStartLayout` with safe hex-encoded job/partition path segments and conventional journal/provenance/receipt/handoff locations.
- Adds `MigratableJobStarterDestinationRunner`, allowing existing Queue Fabric and file/manual receivers to route committed destination starts through the same starter while retaining the acknowledgement protocol.
- Adds qualification for crash-after-claim retry, successful replay, conflicting start IDs, recovery dispatch, handoff duplicate suppression, queue/file bridge behaviour, receipt-integrity failure and safe durable layout.
- API `migratable.job/0.2` remains compatible; the new starter sub-contract is `migratable.job.start/1`.

# v0.2.2

- Changes live job/migration status from direct-queue semantics to Queue Fabric topic publish/subscribe with ordinary subscriber queues as delivery endpoints.
- Adds `MigratableJobTopicStatusPublisher`, `MigratableJobStatusTopicCodec` and safe hex topic addressing helpers.
- Publishes retained `migratable.job.status/1` snapshots after authority persistence, including monotonic migration `sequence` for stale/redelivery rejection.
- Keeps migration commands and acknowledgements on addressed direct queues.
- Makes status observation explicitly non-authoritative: fan-out failure records `STATUS_PUBLICATION_FAILED` provenance and does not roll back migration authority.
- Adds acceptance proving independent UI/logger fan-out, late retained subscription, monotonic status sequence and observer-backpressure fail-open behaviour.
- API remains `migratable.job/0.2`; the coordinator gains one optional trailing status-publisher collaborator.

# Changelog

## 0.2.1 — 2026-09-13

- Corrects Crypto qualification: high-throughput SHA-256 is the existing Crypto Foreign Runtime/OpenSSL provider path, not an expected pure-Rexx debug path.
- Adds explicit JobNode/Migratable Job provider-evidence qualification.
- Removes the intrinsic-durability `FastDigest` test double; the test now uses the real `JobNodeDigestProvider` with Foreign Runtime acceleration.
- Runs the SHA-heavy hardening probe with the same resident Crypto provider.
- API remains `migratable.job/0.2`; migration semantics are unchanged.

## 0.2 — 2026-09-13

- Makes migration transaction journaling a coordinator-owned boundary.  When a
  `MigratableJobDurableJournal` is supplied, creation and every material state,
  evidence, ownership, placement and handoff transition are snapshotted by the
  coordinator rather than relying on the caller to remember to append.
- Splits planned source handoff into independently recoverable ownership-fence
  and admission-release operations; each is journalled before the next
  authority action.
- Adds allocator-authoritative crash-window reconciliation.  After Job-to-Node
  durable state is restored, a migration can recover a fence or replacement
  placement that committed immediately before the coordinator process died.
- Adds `AWAITING_DESTINATION` and explicit handoff/acknowledgement semantics.
  Queue insertion or file creation is not treated as proof that the destination
  is running.
- Adds a common transport-neutral `MigratableJobHandoffInstruction` and
  destination acknowledgement contract.
- Adds QueueChannelFabric handoff using QueueGraph-persistable primitive
  payloads, suitable for Queue Fabric store-and-forward and its socket
  transport.  Adds a destination worker and reverse acknowledgement reader.
- Adds digest-protected `.mjob` file handoff for manually carried/offline
  control transfer.  Checkpoint bytes remain the Storage Fabric data plane and
  can be copied separately; SHA-256 transfer evidence is rechecked locally
  before manual start when present.
- Retains direct in-process resume as the default compatibility mode.
- Durable journal STATE2 records handoff mode/id/reference while retaining read
  compatibility with v0.1 STATE snapshots.
- Adds qualification for intrinsic durability, allocator crash reconciliation,
  portable file/manual start and bidirectional QueueChannelFabric handoff.

## 0.1 — 2026-09-13

Initial planned-migration checkpoint: safe pause/checkpoint, source fence,
Job-to-Node re-placement, resumable Storage Fabric transfer, explicit commit
and direct resume with durable transaction/provenance helpers.
