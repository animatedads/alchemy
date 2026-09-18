# Architecture

```
running ooRexx application
        |
        | cooperative Inspector attachment / triggers
        v
 Inspector Clouseau
        |
        | immutable observation snapshot
        v
ClouseauStorageFuseBridge
        |
        | Storage virtual files only
        v
StorageFuseGenerationStore / StorageFuseOperationCore
        |
        +--> FUSE3 native adapter / RPC seam
```

The bridge is intentionally one-way. Inspector probes may be temporarily installed by Clouseau to observe object slots, but this module never injects or modifies application values. The Storage projection is observation/evidence, not an alternate object mutation API.

Method virtual files expose Clouseau's own method-origin analysis (`local_declared`, inherited superclass, mixin/secondary superclass, override, etc.) and source availability. Attribute virtual files come from Clouseau probe-slot evidence and retain value class/kind/OID alongside their displayed value.