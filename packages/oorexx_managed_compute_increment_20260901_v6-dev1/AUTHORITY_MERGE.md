# Remote workload authority merge

## Kept

- Job-to-Node Allocator owns hard eligibility, ranking, ownership epoch and placement leases.
- WLU remains resource admission/settlement authority.
- Queue Fabric owns durable delivery, priority, claim/ACK/NACK and recovery.
- Managed Node owns finite execution on an already-selected node.
- Work Bundle owns immutable workload-content/provenance proof.
- API Client owns FETCH egress route/session authority when FETCH is implemented.
- Terminal owns SSH/PTY/host-key/credential/bootstrap automation.
- Secret Broker owns secret references/leases when secret injection is implemented.

## Retired duplicate from Remote Host v0.2-dev1

The following are not carried forward because Managed Node provides stronger equivalents:

- RemoteHostQueuedWorkSpec
- RemoteHostQueuedDispatchEnvelope
- RemoteHostQueueWorker
- RemoteHostQueueResult
- a second execution-operation vocabulary

## Retained concepts, refactored into Host Profile

- stable node/provider identity;
- provider topology and cost provenance;
- queue-ready bootstrap gate;
- runtime generation (`boot_id`) observation;
- durable capability versus transient capacity separation;
- Terminal-owned bootstrap port abstraction.
