# Institutional Policy v0.8 architecture

Institutional Policy describes institutional deployment mechanics, not Legal, Security, Brand or other domain semantics.

```text
reviewed domain policy artefact
        |
        v
publication + authority evidence
        |
        v
global lifecycle
        |
        v
deployment topology
        |
        +---- ordinary exact-version routing
        |
        `---- bounded progressive overlap
                    |
                    +---- STAGED / CANARY
                    |
                    +---- immutable rollout observations
                    |
                    +---- fixed rollout gate
                    |       sample thresholds
                    |       metric thresholds
                    |       evidence window/freshness
                    |
                    `---- deterministic promotion assessment
                            PROMOTION_ELIGIBLE
                            PROMOTION_BLOCKED
                            INSUFFICIENT_EVIDENCE
```

The rollout gate is embedded in the authorized progressive binding and therefore participates in its semantic identity. Promotion is not a runtime “does this look okay?” judgement. The catalogue computes the assessment from the fixed gate and sealed observations.

Successful deployment bindings retain the exact assessment which allowed promotion. Authorized failed attempts are also retained in the catalogue as audit evidence.

The common layer never converts rollout metrics into domain evidence. For example, false-positive rates can govern whether a Bouncer policy is promoted, but cannot become a finding that makes an individual customer suspicious.

Historical routing remains time-sensitive and deterministic. Future deployment evidence cannot rewrite earlier routing, and stale rollout evidence cannot authorize a future cutover beyond the gate's configured freshness horizon.


## Post-promotion rollback

A progressive authorization may contain independent promotion and rollback gates. Both are fixed versioned artefacts. Promotion widens deployment only after its acceptance gate passes. After cutover, the rollback gate evaluates immutable aggregate observations against explicit degradation thresholds. An eligible automatic rollback creates a normal immutable deployment binding to the exact prior policy and attaches the exact rollback assessment as evidence. Manual authorized rollback remains independent.
