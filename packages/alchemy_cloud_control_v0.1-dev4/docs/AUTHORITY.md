# Cloud Control authority — v0.1-dev4

`alchemy.cloud-control/0.1 RESOURCE` owns provider mutation translation and provider/account selection constraints. It does not own user intent, human confirmation, allocator node identity, XTP topology, or provider credentials.

The generic firewall reconciliation contract is:

```text
(scope, rule, protocol, port?, desired non-empty source set)
    -> preserve unrelated rules
    -> add missing matching sources
    -> remove extra matching sources
    -> leave provider-native rule IDs visible as execution evidence
```

The desired set is semantic input from a higher authority. Cloud Control does not infer peers from addresses or machine names.
