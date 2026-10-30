# Cluster Object / Memory Fabric Gopher sphere v0.1

Continuity sphere for the Alchemy execution-to-memory model: ordinary ooRexx objects move toward fenced resident Memory Fabric blocks, Queue Fabric owns durable store-and-forward, XTP owns the protected named-service carrier, and placement remains external in Job-to-Node.

Start with:

    gopher --profile cluster-object-memory context cluster-object-memory --full
    gopher --profile cluster-object-memory search "execution follows memory" --sphere cluster-object-memory
    gopher --profile cluster-object-memory search "MOVE_UNCERTAIN" --sphere cluster-object-memory
    gopher --profile cluster-object-memory search "field receipt" --sphere cluster-object-memory

The sphere documents authority and qualification boundaries. It is not executable transport code and must not be used to infer live MU/MI readiness.
