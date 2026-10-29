# Candidate3 local qualification — 27 October 2026

Dependencies inspected / executed: Memory Fabric v0.1-dev10, XTP v0.1-dev25, Service Descriptors v0.1-dev1, Operational Planner v0.1-dev5, Socket Provider v0.1-dev16, ooRexx 5.3.0 r13196 from the supplied Ubuntu debug `.deb`. Source was extracted in an isolated path; no host installation or ED209 deployment.

## PASS — executed locally

- `rexxc src/MemoryXtpReadIngress.cls` (r13196 syntax compiler).
- `tests/run_ingress.sh`: authenticated identity resolution with fixture provider, independent ACL fixture deny/revoke, wrong local XTP service route/class, bounded 16MiB/default 60s TTL, page alignment, same-process duplicate ID, expired request, stale block generation and provider reincarnation fencing.
- `tests/test_capacity_admission.sh`: sender-side epoch/revocation verification, governor dev5 two 30% scoped tickets / 60% aggregate, capacity contraction, class emergency suspension and restoration.
- `tests/run.sh`: two-source aligned-window planning and real ServiceDescriptor/operational class validation.
- `tests/test_memory_xtp_admission_wire.sh`: separate native ooRexx sender/listener processes with XTP dev25 named FIRST and capacityRate, 60KB controls (first observed 0.202082s, second 0.401840s).
- `python3 tests/test_contract_static.py`: six JSON sphere articles, glossary, cross-references and publication path map.

## Explicit unqualified boundaries

The read ingress is an executable authority gate only; it is **not wired to native XTP listener** and **has no production authentication/ACL provider**. The test identity and ACL implementations are intentional fixtures. There is no real remote memory page I/O, page checksum/merge, durable replay ledger, sender/receiver capacity coupling, ED209 carrier qualification or multicast service-admission proof. XTP service-name/KEY/ACK is not a read credential, memory ownership, application commit or proof of all multicast receivers.

Gopher sphere JSON structural checks passed; Gopher VALID/CLEAN activation was not executed.

Candidate4: added a verifier with alternating authenticated identities, which must be rejected during admission.
