# Memory Fabric — XTP service integration (candidate 1)

**Status:** additive contract and executable qualification candidate, 2026-10-16.
**API:** `memory.fabric.xtp-transfer/0.1` (proposed). **No production dispatch; no remote memory mutation.**
**Base:** `oorexx_memory_fabric_v0.1-dev10.zip` with XTP dev23, Service Descriptors dev1, Socket Provider dev16 and Operational Degradation Planner dev2.

This increment applies the Storage Fabric multi-source example to **Memory Fabric resident block access**. It reuses the existing service registry, operational planner, XTP named-service manager, Memory Fabric provider authority and XTP transport. It does not create a parallel transport or pretend that multicast membership grants memory authority.

## Example: two resident memory suppliers

`MI1/MU2` requires block `BLOCK-A`, generation 8, aligned window `[0,64 MiB)`. A service-addressed discovery operation `memory.block.locate` finds the current authoritative resident replicas on logical peers `mu5-mem` and `mu7-mem`. (This discovery operation is **a target contract**, not yet wired to XTP MULTI.) Both offer the entire window with provider epochs and evidence identifiers. The independent receiver policy for registered service `memory.block.read`, class `normal.memory`, has per-context 30%, at most two simultaneous contexts and aggregate inbound 60% in NORMAL state.

The actual candidate planner produces:

| Context | Registered service | Logical peer | Byte window | Class budget |
| --- | --- | --- | --- | --- |
| 1 | `memory.block.read` | `mu5-mem` | `[0,33554432)` | 30% |
| 2 | `memory.block.read` | `mu7-mem` | `[33554432,67108864)` | 30% |

These are 2 MiB-aligned, non-overlapping windows. Together they cover exactly 64 MiB; the policy admits at most 60% aggregate. Unlike ordinary Storage Fabric ranges, a Memory Fabric source offer additionally binds block identity, generation, provider identity, owner epoch and provider incarnation generation. The real Memory Fabric registry is consulted; a provider reincarnation invalidates its old offer. **The budgets are correct planner outputs, not proof that the current named-service native socket enforces percent pacing end-to-end.**

The original Storage Fabric reference is `PARALLEL_FETCH.md` in Storage Fabric dev22: 100 MB request, two 50 MB ranges, `normal.storage` 30% × 2 / 60%. Memory Fabric uses a **different service class and page-aligned windows**; it never assumes that file ranges and resident memory are interchangeable.

## Contents

- `src/MemoryXtpTransferPlanning.cls` — request/offer, authoritative epoch checks, two-replica page-range splitting, operational policy from registered service, named-service control shim. Does not send remote block contents.
- `tests/test_memory_xtp_planning.rex` — executes using **real Memory Fabric dev10 registry**, real Service Descriptors and XTP named manager (recording backend for this test). Tests split, epochs, class and send invocation.
- `tests/test_real_policy.rex` — uses the **real Operational Degradation Planner dev2**, service registration and class-scoped rules. Verifies NORMAL admission, EMERGENCY bulk suspension and survival of separately governed critical invalidation class.
- `tests/test_xtp_named_service_wire.rex`, `tests/xtp_wire_loopback.sh` — locally qualified **real named-service FIRST transport** to native `xtp-listen` over loopback XTP/UDP with patched dev23 native registration.
- `docs/ARCHITECTURE.md` — service contract, multicast/lease safety, capabilities, boundaries, missing integrations, qualification matrix.
- `docs/xtp_dev23_native_registry.patch` — upstream XTP dev23 native ooRexx registration and listener-scope fixes required by named service ooRexx binding. Apply to **a separate working copy of XTP dev23**; not to system files or original Library source.

## Qualification prerequisites

The tests were run using the **user-supplied** r13196 Ubuntu 16.04 debug ooRexx `.deb` extracted into a temporary directory (not installed system-wide). The patch was applied only to the extracted XTP dev23 source, with a native `.so` rebuilt against the package's `libxtp.a`. The native XTP dev23 `tests/test_named_service.sh` and `tests/test_multicast.sh` also passed locally after the patch. No ED209 production network, L2/raw36 mesh route or end-to-end memory transfer was exercised by this candidate.

Set the following paths to extracted source roots:

```sh
export MEMORY_FABRIC_DIR=/path/to/oorexx_memory_fabric_v0.1-dev10
export XTP_DIR=/path/to/oorexx_xtp_v0.1-dev23
export SERVICE_DESCRIPTORS_DIR=/path/to/oorexx_service_descriptors_v0.1-dev1
export SOCKET_PROVIDER_DIR=/path/to/oorexx_socket_provider_v0.1-dev16
export OPERATIONAL_PLANNER_DIR=/path/to/oorexx_operational_degradation_planner_v0.1-dev2
export REXX_BIN=/path/to/oorexx/bin/rexx
# Ensure LD_LIBRARY_PATH finds the ooRexx runtime library and rebuilt XTP native binding.
./tests/run.sh
./tests/xtp_wire_loopback.sh
```

The second command requires the dev23 XTP native registration patch, the `xtp-admin`/`xtp-listen` executables, and an available temporary UDP loopback port 44997. The first uses automatically created temporary policy/registry files.

## Integration decision

On qualifying XTP routes, send admitted named services via **XTP FIRST addressing then KEY/ROUTE context lookup**, and use XTP's suitable multicast mode for coordination only when named-service admission, receiver population, peer authentication and reliability are actually available. Use L2 inside qualified MI/MU domains, raw36 across permitted peers, and XTP-over-UDP as fallback. Keep native shared/DMA memory block bags for local data access. Where XTP is unavailable, a different **qualified** connector may be selected by the existing transport architecture. Do not invent IP endpoints in Memory Fabric descriptors.

**Not yet production ready:** service-addressed multicast delivery, authenticated recipient admission for distributed memory operations, complete live transport data path, native percent budget enforcement for named service contexts, peer-authorized block/lease checks at receiver ingress and full ED209 qualification. See `docs/ARCHITECTURE.md`.
