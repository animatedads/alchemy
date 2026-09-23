# ooRexx Managed Compute Increment — 2026-09-01 v6-dev1

Development continuation roll-up for allocator-selected managed compute.

## Current execution personalities

```text
                         Generic workload
                               |
                     hard requirements / policy
                               v
                    Job-to-Node Allocator v0.6
                    /           |             \
                   /            |              \
           Managed Node       Colab          HF Space
              durable        ephemeral       managed API
                |                |                |
           Queue Fabric      colab CLI       API Client
                |
        Work Bundle + exact
        task authorization
```

## v6 merge

The previous `oorexx_remote_host_job_v0.2-dev1` is removed from the roll-up. Its useful identity/bootstrap/capacity concepts are retained in the much smaller `oorexx_managed_node_host_profile_v0.1-dev1`; its duplicate queued work-spec/worker/result contract is retired.

Normal durable-node execution is now owned by the supplied `oorexx_oracle_managed_node_increment_20260901_v1`:

- immutable Work Bundle producer proof and file digests;
- allocator placement lease preserved through durable Queue Fabric dispatch;
- exact ManagedTaskAuthorization bound to placement/ownership epoch/task/bundle;
- destination ownership fencing;
- allowlisted runtime + declared bundle entrypoint + argv execution;
- bounded stdout/stderr and isolated staging/cleanup;
- persistent result publication before ACK;
- retry idempotency in-process;
- FETCH and SERVICE fail closed until their proper owning runners exist.

Although the increment was developed for the two OCI nodes, the Managed Node execution contract itself is provider-neutral. OCI identity/topology belongs in the host-profile layer.

## Bootstrap boundary

```text
INITIAL PREPARATION / RECOVERY
    Terminal Machine SSH personality
       -> inspect bare host
       -> build/install + qualify ooRexx
       -> install + qualify managed Queue endpoint
       -> observe runtime generation (Linux boot_id)
       -> publish queue-ready capability

NORMAL OPERATION
    allocator lease
       -> Queue Fabric
       -> ManagedNodeDispatchEnvelope
       -> ManagedNodeAgent
       -> result/evidence
```

This roll-up does not guess or reimplement Terminal SSH. The exact later SSH-capable Terminal artifact remains an external dependency for live bootstrap.

## Durable versus transient node facts

`oorexx_managed_node_host_profile_v0.1-dev1` keeps:

- stable `nodeId` separate from provider resource ID and network address;
- provider/topology/cost provenance as capability tags;
- installed CPU/RAM/disk and installed runtimes in capability generation;
- `boot_id`-style runtime generation in capability evidence;
- queue readiness as hard eligibility;
- free RAM/disk/CPU, WLU/s, queue depth and active jobs as expiring capacity observations.

A reachable machine without a qualified queue endpoint advertises no ordinary managed execution ability.

## Public network transport

Routine work remains Queue Fabric-authoritative, but raw Queue Fabric v0.9-dev4 TCP/HMAC is authentication/integrity only and is not acceptable naked across an Internet-facing node address. The next transport increment is the Managed Node Gateway: node-initiated HTTPS/TLS with server-derived node -> fixed queue binding, while Queue Fabric remains the delivery authority behind the gateway.

## Included packages

- Job-to-Node Allocator v0.6
- Queue Fabric v0.9-dev4
- Alchemy Objects v0.8
- Oracle Managed Node increment v1
  - Work Bundle v0.1-dev1
  - Managed Node v0.1-dev1
- Managed Node Host Profile v0.1-dev1
- Colab Job v0.1.1
- Hugging Face Space Job v0.2.1
- Hugging Face managed endpoint v0.1
- API Client v0.3
- Foreign Runtime v0.22.6
- Crypto v0.8.3
