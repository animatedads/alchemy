# Operational Degradation Planner dev4

Three independent concerns are kept separate:

1. **Operational class** — importance and degradation behavior.
2. **Capacity domain** — a named shared resource with nominal/current byte capacity.
3. **Provider enforcer** — turns a ticket into transport/fabric behavior.

A capacity domain is semantic resource identity such as `mi1-mu2.ingress`, `mu.storage.fabric`, or `ed209f.wan-egress`; it is not a network address. IP/MAC information remains below the provider routing layer.

The governor combines the class decision with the domain state:

- effective context percent = min(per-context cap, THROTTLE rate when applicable);
- refuse when `max_parallel_contexts` is reached;
- refuse when the next reservation would exceed `aggregate_cap_percent`;
- translate the accepted percentage into bytes/sec using the domain's **current** capacity;
- release capacity explicitly when the context closes.

This is intentionally transport-neutral. XTP can enforce the returned byte rate with native scheduling/pacing. Storage Fabric uses the same ticket for fan-in admission. XMPP can instead refuse forwarding. Queue Fabric can hold/defer work. SAMPLE/AGGREGATE remain upstream transformations and never become permission to pass unmodified traffic.
