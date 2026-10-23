# Validation — Cluster Object Transport v0.2

Date: 2026-10-07

Runtime:
- ooRexx 5.3.0 r13196 Internal Test Version

Resolved baselines:
- ooRexx Memory Fabric v0.1-dev6 / `memory.fabric/0.1`
- Object Queue Fabric sources from RexxOS RTO2 Grid v0.1-dev7
- Queue channel API `queue.channel.fabric/0.9-dev3`
- Queue transport contract `queue.transport/2`

Observed qualification:

```text
CLUSTER OBJECT / MEMORY FABRIC / QUEUE FABRIC TEST START
PASS cluster.object.peer/0.2 Queue Fabric carries execution; Memory Fabric keeps bytes resident
```

Additional checks:
- `rexxc` source syntax check: rc=0
- `rexxc` test syntax check: rc=0
- Queue Fabric MOVE used ObjectQueueManager + QueueChannelFabric + transfer receipt path
- QueueGraphPayloadCodec round-tripped a CALL graph containing a fenced Memory Fabric block reference
- MOVE graph contained block identity but not the resident audio payload marker
- destination resolved the block only after Memory Fabric owner/generation validation
- provider reincarnation advanced membership epoch and caused the old block reference to fail closed

Qualification boundary:
- The transport carrier in this package test is QueueInProcessTransport so both queue managers run in one test process.
- RTO2 Grid dev7 already binds the same QueueChannelFabric semantics to authenticated XTP `queue.transport/2`; a real multi-host XTP environment test remains the deployment gate.
- Job-to-Node admission/lease authority is intentionally not reimplemented here.
