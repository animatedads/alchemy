# ooRexx Managed Node Host Profile v0.1-dev1

Provider-neutral identity/capability/bootstrap vocabulary for already-running managed execution nodes.

This package deliberately does **not** execute remote work and does not implement SSH. It supplies the missing node-profile seam around `oorexx_managed_node_v0.1-dev1`:

- stable allocator `nodeId` separate from provider resource identity and network endpoint;
- provider provenance/topology/cost tags;
- exact runtime generation (for Linux nodes normally `boot_id`);
- queue-ready bootstrap gate;
- declared finite task abilities derived from Managed Node task kinds;
- installed CPU/RAM/disk as capability facts;
- free CPU/RAM/disk, Queue depth, active jobs and WLU capacity as expiring observations;
- abstract Terminal-owned bootstrap/recovery port.

## Authority boundary

```text
Terminal / SSH personality
    -> inspect / prepare / recover bare host
    -> ManagedNodeBootstrapReceipt
    -> ManagedNodeHostProfilePublisher
    -> Job-to-Node Allocator v0.6 capability + capacity

normal job
    -> Job-to-Node Allocator placement
    -> Queue Fabric
    -> ooRexx Managed Node agent
```

A node that is online but not `QUEUE_READY` advertises **no managed execution abilities** and therefore cannot receive ordinary managed tasks.

Network endpoint data is intentionally not allocator identity. Provider resource identity (for OCI, the instance OCID) survives address changes; runtime generation changes on reboot and participates in allocator capability evidence/fencing.
