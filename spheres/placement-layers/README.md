# Runtime Placement Layers Knowledge Sphere v0.1

This composite sphere describes the 'where and how' of execution: the seam between workload allocation, node capability, and runtime implementation switching.

## The Layering Seam
The system moves from a logical work request to a physical execution node through these layers:
1. **Job Node Allocator**: Performs hard eligibility checks (Security, Legal, Access, Runtime) before any optimization.
2. **Managed Node Host Profile**: Provides the identity, capability, and bootstrap vocabulary for the target node.
3. **Runtime Reference**: Switches the execution location (local vs remote) while keeping the semantic operation identity.

## Core Invariants
- **Hard Eligibility First**: Security and Access constraints are never 'soft scores' and cannot be outweighed by idle CPU or cost.
- **Node Identity vs Resource Identity**: The allocator uses a stable `nodeId` separate from provider resource identity or network endpoints.
- **Semantic Continuity**: A caller invokes the same class/method regardless of whether Runtime Reference binds it to a local or remote implementation.
- **Capability vs Capacity**: Node capability (what it can do) remains distinct from transient capacity (how much is free).
