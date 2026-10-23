# Change publication projection — single.time.change/0.1

`TimeChangePublication~project` converts a completed temporal comparison to typed advisory records. It refuses malformed input and cannot send anything itself.

Each result carries the institutional intention, date, authority revision pair, both revision witnesses, the comparison rule mode, reason codes, before/after snapshots and optional UTC delta. Repeating the same input yields the same idempotency identity. For `EXPLICIT_SNAPSHOTS` or other non-`SAME_PROVIDER` comparisons, the caller must supply stable `ruleFromSnapshotId` and `ruleToSnapshotId`; absence fails closed.

The identity is collision-unambiguous for its tuple, but neither a signature nor authenticated identity. Input impact records must come from a trusted, validated authority boundary. Consumer code must serialize a stable copy and validate it against its own allowed schema.

ConnectSelector owns routing and policy; a durable Queue Fabric adapter, when built, owns enqueue, replay, authorization and consumer acknowledgement. This class owns **none** of those effects. No event occurrence is automatically rescheduled or dispatched.
