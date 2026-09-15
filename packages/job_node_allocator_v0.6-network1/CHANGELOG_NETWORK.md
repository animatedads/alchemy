# Network extension changelog

## 0.6-network1

- Adds `job.node.allocator.network/0.1` request/reply service over Queue Fabric.
- Adds primitive placement-request / lease / decision codecs.
- Adds advisory PLAN plus authoritative ALLOCATE/CHECK/RENEW/RELEASE.
- Adds durable request-id replay/conflict ledger.
- Adds per-client operation/owner authorization and administrator-bound reply routes.
- Leaves all mutation authority in the existing JobNodeAllocator v0.6 instance.
