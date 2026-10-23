# ooRexx Operational Degradation Planner v0.1-dev3

Transport-neutral registered operational-class policy. dev3 adds explicit capacity scopes so the policy can distinguish per-context bandwidth, admitted parallelism, and aggregate class bandwidth.

State policy syntax:

`disposition:rate:fallback:protected:per_context_cap:max_parallel_contexts:aggregate_cap`

Example `normal.storage` normal state: `allow:100:allow:any:30:2:60`. This means each admitted context may consume at most 30% of nominal link capacity, no more than two contexts are admitted concurrently, and the class is capped at 60% aggregate.

These are planner decisions, not XTP-only fields. XTP can enforce per-context rate natively; Storage Fabric can enforce parallel fan-in and aggregate admission; other protocols may filter, defer or refuse forwarding.

The ooRexx administration surface is `bin/operationalctl.rex`; `opctl` remains the native persistence/decision engine used by the Rexx class wrapper.

## dev3 packaging repair
`make test` invokes `tests/test_registry.sh` through `bash`; test qualification no longer depends on preservation of the executable bit by ZIP extraction tooling.
