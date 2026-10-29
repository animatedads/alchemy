# Architecture: execution follows resident Memory Fabric over Queue Fabric/XTP

## Authority split

| Concern | Authority |
|---|---|
| Memory block identity, provider generation/owner epoch, residency | Memory Fabric |
| Hard placement/admission | Job-to-Node |
| Durable store-and-forward, receiver ACL, idempotent transfer receipt | Queue Fabric |
| Protected named-service carrier, key/principal/session protection | XTP + LDAP Identity/Secret Broker |
| Object snapshot generation, replay fencing, source release | cluster.object.peer/0.2 |
| Route readiness/field evidence | Deployment / injected readiness authority |

## MOVE commit chain

A cluster MOVE is successful only after this chain:

1. Memory target is a fenced reference, not resident payload.
2. The target provider is mapped to the selected cluster/XTP route.
3. The injected readiness authority accepts the route.
4. Queue Fabric writes the object request to its transmission queue.
5. Queue Fabric's XTP transport opens the protected named service with `encrypt` and verifies peer/service/key binding.
6. A separate Queue Fabric verifier authenticates the remote durable `acceptTransfer()` receipt. XTP ACK/DIAG/session close is not enough.
7. The cluster object service on the destination validates the Memory Fabric reference and reconstructs the next object generation.
8. The cluster response returns to the source.
9. Only then does `ClusterObjectMoveCoordinator` release the old source generation.

Any ambiguity leaves the source resident and is represented as `MOVE_UNCERTAIN` by the existing coordinator.

## Why the readiness guard exists

The XTP owner currently has a LOCAL_PASS for dev35 but no field receipt between a real MU and its MI. This component therefore cannot infer live readiness from source presence, a protected local session test, or a configured service name. The default readiness authority returns false. A production composition must inject an authority backed by current selected-route and Deployment evidence.
