# Read-only Migratable Job status consumption — dev8

Source: native `MigratableJobStatusTopicCodec~toDirectory()` in
`migratable_job_v0.2.2/src/MigratableJobStatusTopic.cls` (`migratable.job.status/1`).
This is a projection from a Queue Fabric **topic**, not a command queue or lease authority.

## Integration boundary

Subscribe through a separately authorized Queue Fabric consumer. The subscriber
must transform each native `.directory` payload to JSON **without changing field
names or semantic types**. Feed one JSON snapshot to `cloud-cost status-ingest
FILE`, or NDJSON to `cloud-cost status-watch`. The package does **not** assert
that an arbitrary JSON file came from Queue Fabric and does not implement a
credentialed subscription or claim native delivery. Authorized subscriptions,
retained snapshots, replay and publication failure remain owned by Queue Fabric
and Migratable Job.

Durability: SQLite transaction journal + local SHA-256 record chain (corruption
detection, **not** cryptographic origin authentication). Strict migration and
source lease identities, conservative destination lease and checkpoint binding,
monotonic sequence, timestamp and fence/resume flags. Redelivery is idempotent;
old retained records are ignored; same-sequence differing content is rejected.
Gaps are permitted because retained-topic and subscriber mechanics need not
supply every intermediate revision. No contract allows observer gaps to decide
migration completion. The state file is `migration_observations.sqlite3` under
`CLOUD_ECONOMICS_STATE` and restricted to mode 0600. SQLite writes serialize
concurrent ingestion and audits reject journal tampering.

The observer does **not** perform provider settlement, authenticate a job,
verify checkpoint digests, allocate a node, lease capacity, emit accounting
postings, commission VMs, invoke migrations, or authorize continuation.
Status projection is telemetry. Native durable Migratable Job journal and JNA
ownership remain authoritative; no inference of successful migration from a
status-only `RUNNING` observation.

## CLI

```sh
export CLOUD_ECONOMICS_STATE=/var/lib/cloud-economics-paper
./tools/cloud-cost status-ingest /path/to/subscriber-status.json
./tools/cloud-cost status-watch < /path/to/authorized-subscriber.ndjson
./tools/cloud-cost status-report
./tools/cloud-cost status-audit
```

Tests: `python3 tests/test_migration_status.py`. This dev8 increment was
qualified with the Python standard library and static Bash checks in its
build environment; native ooRexx tests require a separately supplied runtime.

## Upstream refresh

`Job-to-Node Allocator v0.6-network6` is the latest Library revision inspected.
It changes durable lifecycle journal handling and does not change the read-only
status projection documented here. No replacement allocator source is vendored.
