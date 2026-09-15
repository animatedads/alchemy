# Security Effect v0.10 progressive rollout

Two overlapping Security policy versions are allowed only under a bounded, authority-backed Institutional Policy progressive binding.

Canonical sequence:

```text
v1 published and globally serving
v2 published with bounded progressive overlap authorization
v2 global STAGED
v2 pilot CANARY     -> pilot executes v2, ordinary cohort remains v1
v2 global ACTIVE    -> broad cutover to v2
v1 global ACTIVE later -> deterministic rollback to exact v1
```

The router compares matching exact-version deployment bindings by scope specificity, then effective time. The successor's legacy-global state is never enough to displace the prior version merely because v2 was published.

Rollback does not regenerate policy. It selects the exact previously reviewed artefact. Historical replay remains bound to deployment state at the historical action time.


## v0.9 promotion gate

A progressive binding may carry a fixed rollout gate. `STAGED` and `CANARY` deployment collect evidence; promotion of the successor to `ACTIVE` during that rollout is evaluated inside Institutional Policy from immutable observations. Insufficient samples, breached thresholds or stale evidence block promotion. The exact assessment is retained as deployment evidence. Rollback to the prior reviewed policy remains independently available.
