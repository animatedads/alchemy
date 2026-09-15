# Service boundary

The service owns lifecycle durability and correlation, not physical cash truth.

```text
CREATE -> OPEN -> CLOSING -> CLOSED
```

A close attempt may fail while the durable day remains `CLOSING`. The caller must obtain corrected evidence from the underlying custody/cash-control authorities and submit a new close command with a new exact approval bound to that evidence.
