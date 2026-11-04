# MAS host ConnectSelector binding — PRE25

X'75' and `mvs.alchemy/1` are unchanged. ConnectSelector dev8 is the sole host routing authority; MAS does not implement a second selector or post-dispatch fallback.

Remote RPC/QUEUE/RTO2 routes compose `ConnectAuthenticatedRoutePolicy` with `MasAuthenticatedRouteAuthority`. Exact route policy, authenticated LDAP dev22 identity, independent endpoint-security evidence, and LDAP Identity Directory ACL must all allow. Intent metadata and guest payloads are never authentication evidence.

The MAS Queue personality remains deliberately unmapped to generic enqueue because QPUT/QGET/QDEPTH require stronger synchronous reply semantics than an enqueue receipt.
