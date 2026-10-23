# Managed Compute MU: authority and deployment boundaries

This is an MU control-surface extension, **not** a new allocator, general scheduler, XTP protocol, or GPU server.

The MU uses the upstream `job.node.allocator/0.6` placement lease. Its `MUJobNodeDirectAuthority` calls the actual `JobNodeAllocator~verifyLease(lease,placementRequest,now)`. Production peer deployments should inject the existing network6 CHECK client/response rather than copying or locally trusting remote leases. Every submitted execution must bind the same lease node/capability generation to a registered target. `MUComputeTarget` advertises endpoint capabilities only; the MU itself never advertises accelerator capacity. The node advertised to Job-to-Node must represent the managed execution endpoint, with externally attested capabilities, quota and provenance, not the MU host.

## Targets

* **Colab:** `MUProviderRunnerPort~new(.ColabJobRunner~new(...))`, spec=`ColabJobSpec`. Native runner supplies validation, secrets, CLI sessions, artifact receipts, teardown.
* **ZeroGPU:** `MUProviderRunnerPort~new(.HFSpaceJobRunner~new(...))`, spec=`HFSpaceJobSpec`. Native runner supplies allowlisted Gradio endpoint, quota and output receipts. ZeroGPU grants a function quota rather than a VM lease.
* **Windows:** `MUWindowsAgentPort` accepts an injected authenticated transport client. The Windows-side `Invoke-ManagedComputeWindows.ps1` is a *local* constrained agent for already-provisioned Windows hosts. It does not operate Linux-host Windows containers or create an unauthenticated RPC listener. Image must be digest-pinned, in local allowlist, and its entrypoint fixed in the image. It cannot be started from a Linux Docker daemon.

## Replay / crash rule

Before calling a provider, the MU records `CLAIMED` in a local append/close ledger. Repeating that request ID, including after an MU restart, yields `REPLAY_HELD` regardless of whether the provider call returned. A changed tuple is `REQUEST_ID_CONFLICT`. Unexpected provider receipts yield `EXECUTION_UNCERTAIN`. The MU *never* auto-replays such jobs; inspect provider history / artifact receipts and reconcile through Migratable Job and JobNodeExecutionLifecycle before authorizing a new attempt.

This local ledger is a development substrate, not a production journal with fsync/replication. **Do not enable production dispatch** until the MU uses a durable replay ledger and durable Queue Fabric request/reply, with atomic claim and provider idempotency, plus RTO2 membership generation revalidation. Host authenticity and quota evidence must be supplied by the existing identity/compute authority; `MUComputeTarget` fields alone are not proof. The controller has no independent membership/migration/lease authority.

## Exact upstream versions inspected

Job-to-Node v0.6-network6; RTO2 Grid v0.1-dev14; Colab Job v0.3-dev1; Hugging Face Space Job v0.3-dev1; Managed Endpoint v0.3-dev1; Generalized Compute Intentions v0.1-dev4; Migratable Job v0.2.6; Queue Fabric v0.9-dev6; Connect Selector v0.1-dev5. Upstreams remain separate packages and are never vendored in this deliverable.
