# Live job status subscriptions

## Rule

Live status is publish/subscribe observation. It is not an addressed command.
The authoritative migration journal and Job-to-Node ownership state always win.

## Queue Fabric mapping

Define a QueueTopicFabric topic such as:

```text
name: MIGRATABLE.JOB.STATUS
root: migratable/job/status
```

`MigratableJobTopicStatusPublisher` publishes one retained
`migratable.job.status/1` snapshot at:

```text
job/<hex job id>/migration/<hex migration id>
```

Hex encoding keeps arbitrary job and migration identifiers out of the Queue
Fabric `+`/`#` wildcard syntax. A subscriber attaches its own ordinary queue:

```rexx
ignore = topics~subscribe("OPS.UI", "MIGRATABLE.JOB.STATUS", -,
  .MigratableJobStatusTopicAddress~jobPattern(jobId), "OPS.UI.STATUS", -,
  "TEMPORARY", "admin")
```

Use `MigratableJobStatusTopicAddress~allPattern` for an all-job observer. Topic
subscriptions are wiring authority: the subscribing principal must have Queue
Fabric SUBSCRIBE authority on the topic and MANAGE authority on its destination
queue.

## Semantics

- One publication fans out to every matching subscriber queue.
- Subscriber consumption is independent; one consumer cannot steal another's
  status observation.
- `sequence` is the migration-local monotonic state revision and lets consumers
  discard stale/redelivered observations.
- Retain is enabled by default, giving a late subscriber the current snapshot.
- Subscriber delivery may be persistent when requested independently of the
  authoritative migration journal.
- Queue Fabric distributed topics may propagate subscriber interest between
  queue managers; do not replace this with per-observer direct remote queues.
- Fan-out failure is telemetry/provenance failure, not migration failure. The
  coordinator records `STATUS_PUBLICATION_FAILED` and continues from its durable
  authority state.

## Separation from control queues

The following remain direct/addressed queue traffic:

- migration resume/handoff command to the selected destination;
- destination acknowledgement back to the coordinator;
- any explicit operator command whose recipient owns a control action.

That separation prevents observation topology from acquiring execution authority.
