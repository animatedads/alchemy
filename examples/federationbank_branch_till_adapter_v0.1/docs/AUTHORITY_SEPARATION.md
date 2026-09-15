# Authority separation

```text
Staff Authority reference
        |
Branch Cash transfer + checker + policy
        |
        v
Branch Cash Authority Envelope
        |
        v
Branch/Till Adapter
        |
        +--> exact Till internal-cash instruction
        +--> independent Till checker approval
        |
        v
Teller Till physical custody
```

A missing or mismatched Branch Cash authority envelope is rejected before the till is touched. A valid Branch Cash envelope does not bypass till custody, branch/currency matching, local checker separation-of-duties, physical amount binding, or till idempotency.
