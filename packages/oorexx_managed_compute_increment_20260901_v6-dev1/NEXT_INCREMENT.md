# Next increment — Managed Node Gateway

Target architecture:

```text
OCI node ManagedNodeAgent/GatewayClient
        |
        | outbound HTTPS/TLS only
        v
Managed Node Gateway (controller edge)
        |
        +-- derives node identity from authenticated binding
        +-- maps node to one fixed Queue Fabric work queue
        +-- never accepts client-selected queue names
        +-- returns queue graph payload for claimed package
        +-- maps ACK/NACK/result to the existing manager
        v
Queue Fabric
```

Required properties:

1. node initiates all public-network connections;
2. TLS confidentiality and server identity verification are mandatory;
3. preferably mTLS or an equivalent short-lived node credential, with node identity derived server-side;
4. queue binding is deployment authority, not request data;
5. claim token never becomes reusable execution authority outside the bound node/session;
6. Queue Fabric remains authoritative for claim/ACK/NACK/recovery;
7. Managed Node placement/task/bundle proofs remain unchanged across the gateway;
8. bounded long-poll/backoff; no synthetic idle traffic to evade provider reclamation;
9. Work Bundle HTTPS repository can share the TLS edge but remains immutable digest-addressed content;
10. live OCI bootstrap still uses Terminal SSH only until the queue endpoint is qualified.
