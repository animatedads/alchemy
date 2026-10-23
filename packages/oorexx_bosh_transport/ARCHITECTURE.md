# Architecture

```text
upper protocol binding (optional, separate package)
                 |
                 | opaque namespaced body attributes + payload
                 v
          BOSH logical stream
                 |
                 | HTTP exchange authority
                 v
             HTTP / HTTPS
                 |
        lower stream/socket selector
                 |
          TCP / XTP / ...
```

BOSH owns RID/SID sequencing, BOSH request/response envelopes, logical-stream buffering and termination. The upper binding owns the meaning of any namespaced extension attributes and payload. Reserved BOSH attributes cannot be overridden through the extension seam.

Observation is dependency-neutral in the core. The optional Instrumentation Mesh adapter observes only bounded operational facts and grants no management authority.
