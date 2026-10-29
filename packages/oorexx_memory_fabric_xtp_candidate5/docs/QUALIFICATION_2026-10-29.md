# Memory Fabric XTP Candidate 5 — local qualification (2026-10-29)

Baseline: supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb`, extracted to an isolated test root; Memory Fabric dev10 and Service Descriptors dev1 from Library; Operational Degradation Planner dev5; **historical** XTP dev25 for inherited capacity planning tests. The production target for new protected read adapter is **XTP dev34** from GitHub, `packages/oorexx_xtp_v0.1-dev34`.

| Test | Local result | Boundary |
|---|---|---|
| `tests/run_ingress.sh` | PASS | Real registry and service objects; fake ACL/authenticator from previous candidate |
| `tests/run_protected_read_bridge.sh` | PASS | Real registry and services; test-only dev34 accepted-socket and key records |
| `tests/run.sh` | PASS | Inherited two-supplier plan and operational policy; historical dev25/native |
| `tests/test_capacity_admission.sh` | PASS | Inherited dev25 capacity/governor policy and fencing tests |
| `rexxc` on all four source classes | PASS | Interpreter r13196, test fixture dependency path for dev34 class |
| `tests/test_contract_static.py` and `sphere/tests/run.sh` | PASS | Seven-article JSON, source/provenance and publish map checks |

The dev25 native library was absent initially; it was built against the exact supplied ooRexx debug headers and Planner dev5, then inherited tests passed. No borrowed native dev25 result is asserted as dev34 security qualification.

**NOT RUN / OPEN:** real XTP dev34 native encrypted listener accepted-socket integration, real LDAP/Secret Broker key refresh, production ACL integration, second-process protected read, memory page publisher/checksum/receipt, L2/raw36 ED209 path, per-group multicast keys, canonical Gopher activation/VALID+CLEAN. XTP's own published `VALIDATION_DEV34.txt` is upstream evidence only. No server deployment was performed, and Autobuilder was not running.

Remote memory data is confidential: no XTP clear/authenticate-only mode, key-file fallback for read authority, replayed request or unqualified multicast payload is accepted by this adapter. Public `XtpNamedAcceptedSocket` fixture is test-only and must not appear on a production Rexx path.
