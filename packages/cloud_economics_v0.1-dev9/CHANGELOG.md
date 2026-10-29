## 0.1-dev9 — read-only usage and reported charge reconciliation (2026-10-29)

- Added `tools/financial-evidence`, a standalone read-only observer of exact-decimal unmanaged baseline, usage and provider-reported charge records, correlating case/job/lease/period/currency.
- Durable append-only SQLite observation journal; in-transaction SHA-256 local integrity chain; idempotent replay and conflict detection; invoice-line uniqueness and bounded atomic JSONL batches.
- `cloud-cost reconcile-ingest`, `reconcile-report`, `reconcile-audit` CLI entry points. No changes to paper ledger or allocation/migration authorities.
- Crucial terminology: reports **UNVERIFIED_COUNTERFACTUAL_DELTA**, never realized savings or an authenticated provider invoice. Unverified/fabricated source metadata cannot be promoted to authority.
- Seventeen new automated tests for replay, duplicate invoice lines, scope/currency/lease mismatch, tamper, atomic rollback, insufficient evidence and explicit nonauthorization.
- No live external provider billing adapter, actual spend, deployment, LDAP/HTTPS implementation or ooRexx native runtime qualification in this increment. Python observer is deliberately an isolated evidence boundary, consistent with dev8's existing observer.

## 0.1-dev8 — durable read-only migration status observations

- Read-only ingestion of the native Migratable Job v0.2.2 status projection
  (`migratable.job.status/1`); no implementation of Queue Fabric subscriber authority.
- Retained-snapshot, stale-order, redelivery, identity and rollback safeguards.
- Atomic SQLite journal with local tamper-evident chain and independent audit;
  disconnected from paper purchase accounts and migration dispatch.
- Adds `status-ingest`, `status-watch`, `status-report`, `status-audit` commands.
- Reviewed JNA network6 lifecycle durability delta; no upstream code copied.
- Python-sidecar tests; native runtime regression not rerun in dev8 environment.

# v0.1-dev7 (2026-10-11)

- Added `CloudMigrationContinuationBridge.cls` with native `MigratableJobDefinition` / `MigratableJobDestinationPolicy` preflight, bound to the exact JNA source lease, workload request, selected offer and Memory Fabric destination execution-context advisory.
- Separately added read-only transfer-record reconciliation for `MigratableJobMigration`, `MigratableJobCheckpointResult`, `MigratableJobCheckpointManifest` and `MigratableJobTransferResult` with source/ownership/runtime/checkpoint/target/verification cross-checks.
- Added explanatory transfer-size cost variance; it is a retrospective modelling estimate, not a provider invoice, authenticated checksum, fresh capacity lease, spending authority or migration commit.
- Qualifies against `job_node_allocator_v0.6-network5`, `oorexx_memory_fabric_v0.1-dev10`, native `migratable_job_v0.2.2` packaged with Audio V9 and supplied ooRexx r13196; all Cloud Economics regressions preserved.
- Observed upstream JNA network5 lifecycle `RESULT` bug and runtime reconciliation syntax failure, not patched here. Native MJob `bytesTransferred` constructor rounds some large byte values at default numeric precision: model cost tolerances reflect this; exact invoice reconciliation must use a precision-safe authoritative byte source.
- Real migrations, cloud purchases, remote transport, live provider authority, and final financial settlement remain disabled.

# v0.1-dev5 (2026-10-08)

- Implemented native ooRexx `CloudMigrationEconomics` advisory compare of future stay/move cost, excluding sunk spend, with committed prepaid source seconds, minimum billing quanta, checkpoint/restore, state transfer network/I/O, startup, storage, stop fees, deadline/downtime gates, Spot risk provision and monetary/percent hysteresis.
- Introduced checkpoint-only mobility screening, explicit original intention and route reference preservation, data residency/runtime/capacity/lease assertion gates and a minimum residence period against oscillating migrations; output remains not dispatchable.
- Added versioned, checksum-protected `ingest-mobility` running-job and route snapshots; read-only `migration-preview`, local-lock `migration-tick`, `opportunities`, and continuous watcher polling. Advisory records never post to `accounts.tsv` or pretend to be purchases.
- Added native comparative fixture and CLI tests for cheaper nominal tariffs losing to billing minimums, true future savings, prepaid sunk charges, costly transfer, state-data freshness, wrong jurisdiction, capacity veto, cooldown, checkpoint veto, budget/deadline, ledger isolation and tamper detection.
- No live route execution, purchasing, cryptographically verified capacity/intentions, or invoice reconciliation.

# v0.1-dev4 (2026-10-08)

- Introduced `CloudWholeJobEconomics.cls` with fully itemized paper execution-cost alternatives, billing minima/quanta, ingress/egress, storage, I/O, checkpoint runtime and risk-related recovery cost; explicit segmented Memory Fabric traffic.
- Added versioned, atomically switched `ingest-economics TERMS PROFILES` snapshots and `preview` read-only comparison. Complete native semantic validation precedes activation.
- Enabled opt-in whole-job pricing in the *existing* paper scheduler; backwards-compatible dev3 behavior when no economics configuration exists.
- Included component-sum evidence and cost-input SHA-256 snapshot hashes in decision receipts; audit rejects cost-component tampering; corrected credit posting precision and arbitrary replay-order sum tolerance.
- Added live ooRexx tests and end-to-end daemon/ledger integrity qualification; no cloud purchase or migration authority introduced.

# Changelog

## 0.1-dev3 (2026-10-08)

- New opt-in read-only AWS EC2 Spot history collector with EC2-reported instance
  hardware facts, per-AZ last-effective tariffs, historical-price timestamps
  and source-response fingerprint sidecars. No capacity or purchase assertions.
- New opt-in GCP Compute Engine Billing v1 component-SKU observer with explicit
  SKU allowlist, USD billing-unit preservation, exact region matching, full
  bounded pagination and fail-closed rejection of unsupported tiered tariffs.
  GCP component prices stay out of full-instance offer/booking records.
- Persist separate GCP SKU/region/unit price history; add `trends`, `components
  GCP`, `evidence AWS` read commands with stale/error gating.
- Rate-limit live provider polling (AWS 10min, Azure 30min, GCP 1h default),
  preserving independent source status for all registered providers.
- Strengthen imported normalized quote validation against duplicate/colliding
  IDs, wrong units, malformed numeric charges and public-source authority
  forgery. Clear scratch price deltas before every poll to avoid replay.
- Add offline response-mocked AWS/GCP observer + fail-safe tests. All existing
  dev2 accounting, scheduler and estate-authority interfaces remain intact.
- Still `PAPER_ONLY`: absolutely no new cloud provisioning operations.

# v0.1-dev2

- Added `CloudEconomicAuthorityPlanner` and `CloudEconomicAuthorityHandoff`: retains genuine Generalized Compute Intentions route/candidate objects and respects compute/allocation/WLU/router vetoes before ranking offers. Advisory only, never dispatchable.
- Added Memory Fabric capacity-plan and registry matching: complete two-fragment, same-site allocation from native upstream objects is required to rank segmented 32+32 GiB; quote flags alone are insufficient.
- Added optional real JobNodeAllocator eligibility policy gate for known existing nodes, checking explicit offer/node binding, same-job identity, minimum memory/CPU, runtime, jurisdiction, observation freshness and upstream hard constraints. Revalidation and lease acquisition remain external.
- Added local `flock` single-writer state lock (no HA claims), recovery-first accounts integrity audit, `cloud-cost audit` command, corruption freeze, native bridge/veto tests, a real concurrent-lock test, and tampered-ledger regression tests.
- Kept all providers paper-only; no purchase or execution code introduced.

# v0.1-dev1

- Separate ooRexx `cloud.economics/0.1` paper-only economic planner, explicit hard-fail access, capacity, region/jurisdiction/runtime, currency and quote-age checks.
- On-demand, Spot, and two-provider Memory Fabric planning for explicitly segmented jobs with same-site and fabric-certification gates.
- Per-job and portfolio budget, job duration/earliest/latest-completion, forecast hold, replay-safe paper ledger, event receipt, and unmanaged baseline savings.
- Dynamic bridge consuming the actual Generalized Compute Intentions discovery/planned-admission route and respecting vetoes.
- 23-provider status discovery and normalized feed polling; public Azure Retail Prices read-only adapter; no live purchase functions.
- Optional estate Instrumentation Mesh emitter.
- Real ooRexx runtime tests, upstream Memory Fabric cross-check, mocked price-feed qualification, rebooking after simulated time window, and systemd sample.

## 0.1-dev6 — 2026-10-09

Added read-only native running-job migration authority bridge; actual issuer-side allocator lease verification, lifecycle state, destination JNA policy, and Memory Fabric execution-context constraints. No remote invocation, migration execution, or cloud purchase. Added native tests and discovered upstream lifecycle `observe` regression (no unauthorized patch). See `docs/NATIVE_MIGRATION_AUTHORITY_DEV6.md`.
