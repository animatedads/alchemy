# Memory Fabric — XTP service + capacity admission (candidate 2)

**2026-10-23.** Proposed additive `memory.fabric.xtp-transfer/0.1` API. The package is independently importable beside Memory Fabric dev10. **Not production distributed-memory transport.** The Library source baseline is XTP dev25, Operational Degradation Planner dev5, Service Descriptors dev1, Socket Provider dev16, and Memory Fabric dev10. The Storage Fabric dev23 multi-source fetch design is the *processing analogy*, not a dependency.

## Delivered increment

- `MemoryXtpTransferPlanning.cls`: page-aligned two-source planning with an actual aggregate-class concurrency bound (rather than reporting a fictitious effective minimum when contexts overbooked). This remains planning-only.
- `MemoryXtpAdmission.cls`: **new** block-authority and live transport capacity-ticket adapter. For a current owner, it resolves the real Memory Fabric block generation/owner epoch/length; nonowner replicas are rejected unless an independent injected trusted verifier validates evidence. It rechecks provider incarnation before every send.
- Shared `OperationalCapacityGovernor` dev5 tickets mediate per-context/aggregate allocation; revocation, current capacity contraction, state reconcile and final release apply without inventing a Memory-specific governor. `MemoryXtpAdmission~sendControl()` derives the operational class and target logical peer from the local named service registration, requires a `capacityRate()` socket, and refuses zero-rate/inactive tickets. It transmits only a bounded **control envelope** supplied by the caller, not remote page contents.
- Verified **actual ooRexx XTP dev25 named-service UDP control transfer with rate pacing**, 60,000 bytes in ~0.20 s at 300 KB/s and ~0.40 s at 150 KB/s, using ooRexx r13196 extracted from the supplied .deb and native code built from dev25. No remote ED209 or true multicast service ingress was exercised.
- New `sphere/` first-class Memory Fabric Gopher documentation candidate, with 5 doctrine articles, glossary, provenance and explicit qualification gaps.

## Execution

For a matching qualified local source/runtime checkout set:

```sh
export MEMORY_FABRIC_DIR=/absolute/path/to/oorexx_memory_fabric_v0.1-dev10
export XTP_DIR=/absolute/path/to/oorexx_xtp_v0.1-dev25
export SERVICE_DESCRIPTORS_DIR=/absolute/path/to/oorexx_service_descriptors_v0.1-dev1
export OPERATIONAL_PLANNER_DIR=/absolute/path/to/oorexx_operational_degradation_planner_v0.1-dev5
export SOCKET_PROVIDER_DIR=/absolute/path/to/oorexx_socket_provider_v0.1-dev16
export REXX_BIN=/absolute/path/to/rexx
# Build XTP native module for this exact ooRexx runtime and set LD_LIBRARY_PATH accordingly.
./tests/run.sh
./tests/test_capacity_admission.sh
./tests/test_memory_xtp_admission_wire.sh
python3 tests/test_contract_static.py
```

The pre-existing `tests/xtp_wire_loopback.sh` remains a separate named-service-FIRST regression. The supplied historical `docs/xtp_dev23_native_registry.patch` was for dev23; **do not apply to dev25** (fixed upstream). `tests/run.sh` demonstrates previous dev23-compatible planner contract with current sources, but its separate policy assertion checks dev2-compatible behavior; new rate behavior uses the dev5-specific tests.

## Essential limits

The local loopback test proves named-service transport of a byte buffer under a capacity ticket, not authentication, sealed payloads, cross-MU service admission, multicast registration, native L2/raw36, remote memory-page correctness, durable checkpoint, or live receiver-side block ingress. The supplied replica-verifier test double simulates trusted evidence and is not a signing implementation. Production use must supply real verified replica authority and peer authentication before effectful operations. See `docs/XTP_ADMISSION_DEV25.md` and the Gopher sphere continuation article.
