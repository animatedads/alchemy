# Change publication projection — single.time.service/0.9

`TimeChangePublication` projects a completed `single.time.impact/0.1` comparison into zero or more typed advisory `single.time.change/0.1` records. The operation has no side effects, no transport dependency, and no implicit clock read.

An event contains institutional intention identity, ISO civil date, both committed authority revisions, both witness checksums, explicit rule comparison mode, reason codes, before/after resolution records, and optional UTC delta. Its collision-unambiguous, length-prefixed idempotency key describes the *comparison*, not a trusted cryptographic identity. This ID is not an authorisation token or a signature.

**Delivery is not implemented in this class.** The `deliverySemantics` value is `UNPUBLISHED_PROJECTION` and `effect` is `ADVISORY_ONLY`. Application code may hand the record to ConnectSelector when authorized, but this does not establish durable delivery or an acknowledgement. For durable delivery a Queue Fabric adapter must own publish, replay, checkpoint, consumer authorization and acknowledgement. No automatic calendar mutation or job dispatch is permitted.

The projection is bounded to at most 366 changes; it rejects malformed/incompatible input. Explicitly distinct timezone-rule providers require immutable `ruleFromSnapshotId` and `ruleToSnapshotId` provenance; otherwise publication fails closed rather than allowing an idempotency-key collision. It makes no promise about the deep immutability of nested `before` and `after` records. Transport adapters must serialise a stable snapshot of the returned record and validate allowed fields before publication.

Test: `REXX_PATH=src rexx tests/change_publication.rex` with ooRexx 5.3.0 and the existing v0.8 source tree. Qualification of the new native test is pending an executable runtime. The v0.8 Python snapshot regression remains independently executable.

## Direction

A later durable publication layer will append a journal entry before emitting, preserve the originating rule snapshots, support explicit consumer checkpoints and idempotent replay, and provide signed/authorized lineage where trust requires it. It must not introduce an alternative to ConnectSelector.
