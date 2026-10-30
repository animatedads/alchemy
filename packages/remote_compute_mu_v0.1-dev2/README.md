# Remote Compute MU v0.1-dev2 — managed external execution (candidate)

Project Alchemy / RexxOS remote compute MU coordinating **Colab**, **Hugging Face ZeroGPU**, **Windows VMs**, and **Windows containers on Windows hosts**.

This is an **implementation candidate**, not a commissioned RexxOS MU, and **not a live provider integration**. It provides an executable, durable, fail-closed reference controller in Python and a tested native ooRexx semantic frontage. Production must bind it to the exact current RexxOS mesh, upstream Job-to-Node, WLU, Storage Fabric, Secret Broker, Connect Selector and provider adapters before live dispatch can be enabled. No provider tokens are required for tests.

## Changes from dev1

- Fixed the ambiguous submission bug: a crash, timeout, provider exception, or lost reply after a possible side effect leaves `UNCERTAIN`. A durable `dispatchKey` can be reconciled with the provider; **automatic resubmission is forbidden**.
- Added local inter-process serialization, 0700 journal directory checks, no-follow opens and fsynced write/replace/directory durability.
- Added restart reconstruction, immutable request-fingerprint conflict checks, and explicit `COMMITTING` fence before Storage Fabric commit (unknown commit outcomes are never replayed blindly).
- Cancellation is `CANCEL_REQUESTED` until the provider confirms `CANCELLED`. Cancelling `UNCERTAIN` never pretends remote work stopped.
- Added per-provider hard gates: Colab resource/accelerator declarations; ZeroGPU Space/operation; Windows VM image reference; Windows-container kernel/isolation and pinned image digest.
- Added native `RemoteComputeMUFront.cls` for ooRexx 5.3.0 r13196 (semantic request validation and injected-controller dispatch; no new selector, no ad hoc RPC transport).
- Added a loadable, data-only LLM Gopher knowledge sphere at `sphere/`, with precise capabilities and limitations.

## Quick qualification

```sh
python3 -m unittest discover -s tests -v
REXX_PATH="$PWD/src" rexx tests/test_front.rex
python3 tests/test_sphere.py
```

The supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb` was **extracted only into a private work directory** to run the native test. The package is not redistributed or installed onto the host. The test consumes no remote compute.

## Dependencies and integration

- **Placement:** Job-to-Node Allocator v0.6 authoritative lease checks (injected; mock in tests).
- **WLU:** external WLU Authority entitlement checks (injected; mock in tests).
- **Storage:** Storage Fabric input readiness, output verification/commit/reconciliation (injected; mock in tests).
- **Colab:** use existing `oorexx_colab_job_v0.3-dev1` and its secret/receipt lifecycle, do not duplicate it.
- **HF ZeroGPU:** use existing Hugging Face Space Job component and supported Space API operation, not an invented dedicated GPU node.
- **Windows:** Windows VM lifecycle and Windows-host container adapters are not yet bound. A Linux Docker host cannot run Windows-kernel containers.
- **Mesh transport:** register the MU as one service through the actual Connect Selector / existing authenticated mesh when available. Queue Fabric is preferable where durable status and command delivery are required but not mandatory for every local call.
- **Migration:** Migratable Job remains the migration protocol and checkpoint/retained-status owner; an ephemeral provider must not promise arbitrary live migration.

The Python controller is reference code until these interfaces are bound. See `docs/ARCHITECTURE.md` and the source tests for the exact state/authority contract.

## 2026-10-29 native mesh ingress increment

Added `src/RemoteComputeMUMeshService.cls`, `tests/test_mesh.rex` and `docs/MESH_INGRESS_DEV3.md`. Transport-derived identity is separated from untrusted envelope content; every operation requires policy admission. Live XTP/LDAP/provider interfaces remain unbound.
