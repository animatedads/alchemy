# Portable Perception Work v0.1 — authority contract

A work identity binds source StorageRef + generation + content digest, source-global microsecond interval, method, pinned model digest and processing options. Execution placement must not alter identity.

A node capability witness includes principal/access, region, CPU/GPU/accelerator support, memory, model availability, input decrypt/materialisation ability, output commit ability, and supported checkpoint schema. All are rechecked by the real admission authority. A matching witness is **not** permission to execute.

For stateful temporal operations, checkpoints include last source PTS, tracking state, association hypotheses and algorithm/model lineage. Chunk overlap is source-time-bound and must be reconciled idempotently. Stateless frame inference can be partitioned without tracking continuation.

Commit receipts must be validated against job identity, current lease epoch, source/model digests and durable Storage Fabric commit. A timeout cannot release a remote execution owner; the existing Migratable Job fencing protocol determines succession. No duplicate authoritative writer.

Outputs are model observations, not original source truth and not human identity. Unsupported dimensions remain UNKNOWN, not zero.
